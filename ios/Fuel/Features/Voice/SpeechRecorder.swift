import AVFoundation
import Observation
import Speech

// On-device-first speech capture for voice meal logging. Egyptian Arabic is the
// primary language (Apple routes ar-EG through its servers, so we do NOT force
// `requiresOnDeviceRecognition`), English is secondary.
//
// Every AVFoundation / Speech dependency lives in this file — the flow view only
// reads `state` and `transcript`. Permission denial and a missing recognizer are
// DESIGNED STATES, not errors: the flow keeps working because the transcript
// field is editable, so a denied mic still leaves a fully usable typed path.
enum VoiceLanguage: String, CaseIterable, Identifiable, Sendable {
  case arabic
  case english

  var id: String { rawValue }

  /// Shown on the language chips. Deliberately NOT localized — each label is
  /// written in the language it selects, the way every bilingual keyboard does it.
  var label: String {
    switch self {
    case .arabic: return "العربية"
    case .english: return "English"
    }
  }

  /// The `lang` code the backend prompts expect.
  var apiLang: String {
    switch self {
    case .arabic: return "ar"
    case .english: return "en"
    }
  }

  /// An example utterance shown under the transcript field.
  var example: String {
    switch self {
    case .arabic: return "أكلت تلات بيضات مسلوقين وتوستتين، ضيفهم على الفطار"
    case .english: return "I ate three boiled eggs and two slices of toast, add to breakfast"
    }
  }
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
    /// No recognizer exists for the chosen language on this device.
    case unavailable
    /// Recognition started but died before hearing anything (broken assets,
    /// no network for a server-backed language, …). `failureDetail` says why.
    case failed
  }

  private(set) var state: State = .idle
  /// The live transcript — partial results while recording, editable after.
  var transcript = ""
  /// The system's own description of what went wrong, for the `.failed` state.
  private(set) var failureDetail: String?
  private(set) var language: VoiceLanguage

  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  /// Text already captured before the current run, so recording a second time
  /// (or after a manual edit) appends instead of replacing what's there.
  private var committedPrefix = ""
  /// Whether the current run produced any text at all — an error after real
  /// speech is a normal stop; an error before any speech is a failure.
  private var sawTextThisRun = false

  init(language: VoiceLanguage = AppLanguage.current == "ar" ? .arabic : .english) {
    self.language = language
  }

  var isRecording: Bool { state == .recording }

  /// Switching language mid-recording stops the current run first — a recognizer
  /// is bound to one locale for its lifetime.
  func setLanguage(_ next: VoiceLanguage) {
    guard next != language else { return }
    if isRecording { stop() }
    language = next
    if state == .denied || state == .unavailable || state == .failed { state = .idle }
  }

  // MARK: - Start

  func start() async {
    guard state != .recording, state != .requestingPermission else { return }

    state = .requestingPermission
    failureDetail = nil
    sawTextThisRun = false

    guard await Self.requestSpeechAuthorization(), await AVAudioApplication.requestRecordPermission() else {
      state = .denied
      return
    }

    guard let recognizer = Self.recognizer(for: language), recognizer.isAvailable else {
      state = .unavailable
      return
    }

    // Anything already in the field (a previous run, or the user's own edits)
    // stays put; new speech is appended after it.
    let existing = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    committedPrefix = existing.isEmpty ? "" : existing + " "

    do {
      try beginAudio(with: recognizer)
      state = .recording
    } catch {
      teardownAudio()
      state = .unavailable
    }
  }

  private func beginAudio(with recognizer: SFSpeechRecognizer) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest.shouldReportPartialResults = true
    // Egyptian Arabic is typically server-backed, so never force on-device.
    recognitionRequest.requiresOnDeviceRecognition = false
    recognitionRequest.taskHint = .dictation
    recognitionRequest.addsPunctuation = true
    request = recognitionRequest

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else { throw RecorderError.noInput }

    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      recognitionRequest.append(buffer)
    }

    engine.prepare()
    try engine.start()

    task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
      // The handler fires off the main actor — extract Sendable values and hop.
      let text = result?.bestTranscription.formattedString
      let isFinal = result?.isFinal ?? false
      let detail = error?.localizedDescription
      Task { @MainActor [weak self] in
        self?.apply(text: text, isFinal: isFinal, failureDetail: detail)
      }
    }
  }

  // MARK: - Stop

  func stop() {
    guard state == .recording || state == .requestingPermission else { return }
    teardownAudio()
    state = .stopped
  }

  /// Clear everything back to a fresh capture (used by "start over").
  func reset() {
    teardownAudio()
    transcript = ""
    committedPrefix = ""
    failureDetail = nil
    state = .idle
  }

  private func teardownAudio() {
    if engine.isRunning {
      engine.stop()
    }
    engine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    request = nil
    task = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func apply(text: String?, isFinal: Bool, failureDetail detail: String?) {
    // Partial results are cumulative for the current run, so assign (never
    // append) on top of the committed prefix.
    if let text, !text.isEmpty {
      transcript = committedPrefix + text
      sawTextThisRun = true
    }
    guard detail != nil || isFinal else { return }
    if state == .recording {
      teardownAudio()
      // Dying with an error before any speech landed is a FAILURE the user
      // must see (broken sim assets, offline server language, …), not a stop —
      // a silent "stopped" here reads as the button being broken.
      if let detail, !sawTextThisRun {
        failureDetail = detail
        state = .failed
      } else {
        state = .stopped
      }
    }
  }

  // MARK: - Locale resolution

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
