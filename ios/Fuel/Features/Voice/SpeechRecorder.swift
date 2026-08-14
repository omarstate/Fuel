import AVFoundation
import Observation
import Speech

// Speech capture for voice logging, with the language detected rather than
// chosen. Egyptian Arabic is the primary language (Apple routes ar-EG through
// its servers, so we do NOT force `requiresOnDeviceRecognition`), English is
// secondary — and since people mix the two mid-sentence, asking them to declare
// one up front was a tax on every single log.
//
// SFSpeechRecognizer is bound to ONE locale for its lifetime, so auto-detect is
// two recognition tasks racing over the SAME input tap: every buffer is appended
// to both requests, and `transcript` always shows whichever candidate currently
// leads (`VoiceCandidateScore`). The winner at the end of a run is published as
// `detectedLanguage` and is what the backend prompt gets told.
//
// Every AVFoundation / Speech dependency lives in this file — the flow views
// only read `state`, `transcript` and `level`. Permission denial and a missing
// recognizer are DESIGNED STATES, not errors: the flow keeps working because the
// transcript stays editable, so a denied mic still leaves a usable typed path.
enum VoiceLanguage: String, CaseIterable, Identifiable, Sendable {
  case arabic
  case english

  var id: String { rawValue }

  /// The `lang` code the backend prompts expect.
  var apiLang: String {
    switch self {
    case .arabic: return "ar"
    case .english: return "en"
    }
  }

  /// An example utterance shown under the transcript field, for the meal flow.
  var example: String { example(for: .meal) }

  /// The same, for whichever flow is asking — what you'd say about food and what
  /// you'd say about a set share nothing but the language.
  func example(for context: VoicePromptContext) -> String {
    switch (context, self) {
    case (.meal, .arabic): return "أكلت تلات بيضات مسلوقين وتوستتين، ضيفهم على الفطار"
    case (.meal, .english): return "I ate three boiled eggs and two slices of toast, add to breakfast"
    case (.workout, .arabic): return "بنش برس تمانين في تمانية، وبعدين خمسة وتمانين في ستة"
    case (.workout, .english): return "bench press 80 for 8, then 85 for 6"
    }
  }

  /// The language the app itself is running in — the fallback when nothing was
  /// spoken at all (a purely typed entry has no detected language).
  static var appDefault: VoiceLanguage {
    AppLanguage.current == "ar" ? .arabic : .english
  }
}

/// Which flow is prompting the user — the recorder itself is identical either
/// way, only the example utterance differs.
enum VoicePromptContext: Sendable {
  case meal
  case workout
}

@MainActor
@Observable
final class SpeechRecorder {
  enum State: Equatable {
    case idle
    case requestingPermission
    case recording
    case stopped
    /// Microphone or speech-recognition permission was refused.
    case denied
    /// No recognizer exists for EITHER language on this device.
    case unavailable
    /// Recognition started but died before hearing anything (broken assets,
    /// no network for a server-backed language, …). `failureDetail` says why.
    case failed
  }

  private(set) var state: State = .idle
  /// The live transcript — partial results while recording, editable after.
  var transcript = ""
  /// Microphone loudness, 0…1, for the waveform. Reset to 0 whenever we stop.
  private(set) var level: Double = 0
  /// The system's own description of what went wrong, for the `.failed` state.
  private(set) var failureDetail: String?
  /// Which language actually won the last run. Nil until something is heard —
  /// typed-only input never sets it.
  private(set) var detectedLanguage: VoiceLanguage?

  private let engine = AVAudioEngine()
  /// The languages racing in the current run, app language first so a dead-even
  /// tie resolves to what the user most likely spoke.
  private var activeLanguages: [VoiceLanguage] = []
  private var requests: [VoiceLanguage: SFSpeechAudioBufferRecognitionRequest] = [:]
  private var tasks: [VoiceLanguage: SFSpeechRecognitionTask] = [:]
  private var candidates: [VoiceLanguage: VoiceCandidateScore.Candidate] = [:]
  /// Recognizers that haven't delivered a final result (or died) yet.
  private var pending: Set<VoiceLanguage> = []
  /// Text already captured before the current run, so recording a second time
  /// (or after a manual edit) appends instead of replacing what's there.
  private var committedPrefix = ""
  /// Whether the current run produced any text at all — an error after real
  /// speech is a normal stop; an error before any speech is a failure.
  private var sawTextThisRun = false
  /// The first error of the run, kept in case EVERY recognizer dies mute.
  private var firstFailureDetail: String?
  /// The last value we wrote into `transcript` ourselves. If the field no longer
  /// matches it the user has typed over the recognition, and late results must
  /// not stomp on their edit.
  private var lastPublishedTranscript = ""

  var isRecording: Bool { state == .recording }

  // MARK: - Start

  func start() async {
    guard state != .recording, state != .requestingPermission else { return }

    state = .requestingPermission
    failureDetail = nil
    firstFailureDetail = nil
    sawTextThisRun = false
    candidates = [:]

    guard await Self.requestSpeechAuthorization(), await AVAudioApplication.requestRecordPermission() else {
      state = .denied
      return
    }

    // A device with no Arabic assets still logs in English (and vice versa) —
    // only losing BOTH is unavailable.
    let recognizers = Self.availableRecognizers()
    guard !recognizers.isEmpty else {
      state = .unavailable
      return
    }

    // Anything already in the field (a previous run, or the user's own edits)
    // stays put; new speech is appended after it.
    let existing = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    committedPrefix = existing.isEmpty ? "" : existing + " "
    lastPublishedTranscript = transcript

    cancelTasks()
    do {
      try beginAudio(with: recognizers)
      state = .recording
    } catch {
      endAudio()
      cancelTasks()
      state = .unavailable
    }
  }

  private func beginAudio(with recognizers: [(VoiceLanguage, SFSpeechRecognizer)]) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    activeLanguages = recognizers.map(\.0)
    pending = Set(activeLanguages)

    for (language, _) in recognizers {
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      // Egyptian Arabic is typically server-backed, so never force on-device.
      request.requiresOnDeviceRecognition = false
      request.taskHint = .dictation
      request.addsPunctuation = true
      requests[language] = request
    }

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else { throw RecorderError.noInput }

    // Both requests are fed from ONE tap — a second tap on the same bus would
    // replace the first, and two engines would fight over the input hardware.
    let liveRequests = activeLanguages.compactMap { requests[$0] }
    // The tap runs on an audio thread ~47×/s; the meter only needs ~30/s, and
    // every extra hop to the main actor is a wasted view invalidation.
    var lastLevelSentAt = 0.0
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      for request in liveRequests {
        request.append(buffer)
      }
      let now = CFAbsoluteTimeGetCurrent()
      guard now - lastLevelSentAt >= 1.0 / 30 else { return }
      lastLevelSentAt = now
      let level = VoiceCandidateScore.normalizedLevel(rms: Self.rms(of: buffer))
      Task { @MainActor [weak self] in
        guard let self, self.state == .recording else { return }
        self.level = level
      }
    }

    engine.prepare()
    try engine.start()

    for (language, recognizer) in recognizers {
      guard let request = requests[language] else { continue }
      tasks[language] = recognizer.recognitionTask(with: request) { [weak self] result, error in
        // The handler fires off the main actor — extract Sendable values and hop.
        let text = result?.bestTranscription.formattedString
        let confidence = result.map { Self.averageConfidence(of: $0.bestTranscription) } ?? 0
        let isFinal = result?.isFinal ?? false
        let detail = error?.localizedDescription
        Task { @MainActor [weak self] in
          self?.apply(
            language: language,
            text: text,
            confidence: confidence,
            isFinal: isFinal,
            failureDetail: detail
          )
        }
      }
    }
  }

  // MARK: - Stop

  func stop() {
    guard state == .recording || state == .requestingPermission else { return }
    endAudio()
    state = .stopped
    settle()
  }

  /// Stop and give the recognizers a beat to deliver their FINAL results before
  /// the caller reads `transcript` / `detectedLanguage`. Finals are what carry
  /// real confidence (and the tidied punctuation), so waiting a few frames for
  /// them is the difference between deciding the language on evidence and
  /// deciding it on a partial-result tiebreak. Bounded, so a wedged recognizer
  /// can never hold up the analyze call.
  func finish() async {
    stop()
    let deadline = Date().addingTimeInterval(0.4)
    while !pending.isEmpty, Date() < deadline {
      try? await Task.sleep(for: .milliseconds(40))
    }
    settle()
  }

  /// Clear everything back to a fresh capture (used by "start over").
  func reset() {
    endAudio()
    cancelTasks()
    transcript = ""
    lastPublishedTranscript = ""
    committedPrefix = ""
    candidates = [:]
    detectedLanguage = nil
    failureDetail = nil
    firstFailureDetail = nil
    state = .idle
  }

  /// Stop the hardware and close the audio side of every request. The tasks stay
  /// alive on purpose — their final results are still worth having.
  private func endAudio() {
    if engine.isRunning {
      engine.stop()
    }
    engine.inputNode.removeTap(onBus: 0)
    for request in requests.values {
      request.endAudio()
    }
    requests = [:]
    level = 0
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func cancelTasks() {
    for task in tasks.values {
      task.cancel()
    }
    tasks = [:]
    pending = []
  }

  private func apply(
    language: VoiceLanguage,
    text: String?,
    confidence: Double,
    isFinal: Bool,
    failureDetail detail: String?
  ) {
    guard activeLanguages.contains(language) else { return }

    // Partial results are cumulative for the current run, so each candidate is
    // replaced wholesale rather than appended to.
    if let text, !text.isEmpty {
      candidates[language] = VoiceCandidateScore.Candidate(
        text: text,
        averageConfidence: confidence,
        isFinal: isFinal
      )
      sawTextThisRun = true
      publishLeadingCandidate()
    } else if isFinal, var existing = candidates[language] {
      // A final that adds no new words still promotes what we already heard —
      // that promotion is what lets it outrank the other language's partial.
      existing.isFinal = true
      candidates[language] = existing
    }

    if let detail, firstFailureDetail == nil { firstFailureDetail = detail }
    guard detail != nil || isFinal else { return }

    pending.remove(language)
    tasks[language] = nil
    guard pending.isEmpty else { return }
    settle()

    guard state == .recording else { return }
    endAudio()
    // Dying with an error before any speech landed is a FAILURE the user must
    // see (broken sim assets, offline server language, …), not a stop — a silent
    // "stopped" here reads as the button being broken.
    if let detail = firstFailureDetail, !sawTextThisRun {
      failureDetail = detail
      state = .failed
    } else {
      state = .stopped
    }
  }

  /// Show whichever recognizer is currently ahead. Called on every partial, so
  /// the displayed text can swap languages mid-utterance — which is exactly what
  /// "we're working out what you're speaking" should look like.
  private func publishLeadingCandidate() {
    guard let index = VoiceCandidateScore.bestIndex(of: orderedCandidates) else { return }
    let winner = orderedCandidates[index]
    guard !winner.text.isEmpty else { return }
    // Late results must never overwrite something the user typed themselves.
    guard transcript == lastPublishedTranscript else { return }
    transcript = committedPrefix + winner.text
    lastPublishedTranscript = transcript
  }

  /// Freeze the decision for this run: republish the leader and record which
  /// language it was, for the backend call.
  private func settle() {
    publishLeadingCandidate()
    guard let index = VoiceCandidateScore.bestIndex(of: orderedCandidates),
          !orderedCandidates[index].text.isEmpty else { return }
    detectedLanguage = activeLanguages[index]
  }

  private var orderedCandidates: [VoiceCandidateScore.Candidate] {
    activeLanguages.map { candidates[$0] ?? VoiceCandidateScore.Candidate(text: "") }
  }

  // MARK: - Audio measurement

  /// Root-mean-square of one buffer's first channel — the standard loudness
  /// measure for a meter. Non-float formats (never seen on iOS input, but the
  /// API allows them) simply read as silence rather than crashing.
  private static func rms(of buffer: AVAudioPCMBuffer) -> Double {
    guard let channel = buffer.floatChannelData?[0] else { return 0 }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return 0 }
    var sum = 0.0
    for frame in 0..<count {
      let sample = Double(channel[frame])
      sum += sample * sample
    }
    return (sum / Double(count)).squareRoot()
  }

  /// Apple scores each recognized segment separately; the transcription's own
  /// confidence is the mean of those. Partial results report 0 across the board,
  /// which `VoiceCandidateScore` knows to treat as "no evidence yet".
  private static func averageConfidence(of transcription: SFTranscription) -> Double {
    let segments = transcription.segments
    guard !segments.isEmpty else { return 0 }
    return segments.reduce(0.0) { $0 + Double($1.confidence) } / Double(segments.count)
  }

  // MARK: - Locale resolution

  /// Every language this device can actually transcribe, app language first.
  /// A device missing one of them races alone rather than failing.
  private static func availableRecognizers() -> [(VoiceLanguage, SFSpeechRecognizer)] {
    let order: [VoiceLanguage] = VoiceLanguage.appDefault == .arabic
      ? [.arabic, .english]
      : [.english, .arabic]
    return order.compactMap { language in
      guard let recognizer = recognizer(for: language), recognizer.isAvailable else { return nil }
      return (language, recognizer)
    }
  }

  /// Egyptian Arabic first, then any other Arabic the device supports; English
  /// prefers the device's own English locale before falling back to en-US.
  private static func recognizer(for language: VoiceLanguage) -> SFSpeechRecognizer? {
    let supported = SFSpeechRecognizer.supportedLocales().map(\.identifier)
    var candidates: [String]

    switch language {
    case .arabic:
      candidates = ["ar-EG", "ar_EG", "ar-SA", "ar_SA"]
      candidates += supported.filter { $0.hasPrefix("ar") }
    case .english:
      candidates = []
      if Locale.current.language.languageCode?.identifier == "en" {
        candidates.append(Locale.current.identifier)
      }
      candidates += ["en-US", "en_US"]
      candidates += supported.filter { $0.hasPrefix("en") }
    }

    for identifier in candidates {
      if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)) {
        return recognizer
      }
    }
    return nil
  }

  private static func requestSpeechAuthorization() async -> Bool {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }
  }

  private enum RecorderError: Error {
    case noInput
  }
}
