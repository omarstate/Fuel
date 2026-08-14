import Foundation

// The decision rules behind dual-language voice capture, as pure Foundation (no
// Speech, no AVFoundation) so they are unit-tested without a microphone.
//
// SFSpeechRecognizer is bound to ONE locale for its lifetime, so "auto-detect"
// is really two recognizers racing over the same audio: the Arabic one and the
// English one both transcribe every buffer, and we show whichever is currently
// winning. `SpeechRecorder` feeds this helper plain values (text, average
// segment confidence, whether the result is final) — it never sees an
// SFTranscription.
enum VoiceCandidateScore {
  /// One recognizer's latest opinion about the same audio.
  struct Candidate: Equatable, Sendable {
    var text: String
    /// The mean of the transcription's per-segment confidences. Apple reports
    /// 0 for partial results, so this is only meaningful once `isFinal`.
    var averageConfidence: Double
    var isFinal: Bool

    init(text: String, averageConfidence: Double = 0, isFinal: Bool = false) {
      self.text = text
      self.averageConfidence = averageConfidence
      self.isFinal = isFinal
    }
  }

  /// Confidences this close count as a tie and fall through to the length
  /// tiebreak. Without it, two partial results (both reported as 0) would be
  /// separated by float noise instead of by how much they actually heard.
  static let confidenceEpsilon = 0.01

  /// A final result only outranks a partial when it carries at least this much
  /// confidence. A recognizer force-fed the WRONG language still finalizes — just
  /// with rock-bottom confidence — and that gibberish must not beat the right
  /// language's still-partial reading.
  static let trustedFinalConfidence = 0.35

  /// Does `lhs` beat `rhs`? In order:
  ///
  ///  1. Anything beats an empty transcription — a recognizer that heard
  ///     nothing must never win just because it finished first.
  ///  2. A FINAL result beats a partial one, but ONLY once its confidence
  ///     reaches `trustedFinalConfidence`. The two recognizers are not evenly
  ///     matched: Arabic is server-backed and delivers its final half a second
  ///     to a second late, while English runs on-device and finalizes fast. An
  ///     unconditional "final wins" therefore handed Arabic speech to whatever
  ///     lookalike English words the fast recognizer settled on. A final that
  ///     confident-less is evidence of nothing, so it skips rule 3 (a partial
  ///     reports 0 confidence and would lose that comparison on noise alone)
  ///     and is judged on length instead.
  ///  3. Higher average confidence, beyond the epsilon above.
  ///  4. More text. A recognizer transcribing the wrong language typically
  ///     latches onto a few short lookalike words, so the one that produced
  ///     more characters is almost always the one that understood the speaker.
  ///     (Comparing character counts across scripts is crude, but this is only
  ///     ever a tiebreak between two readings of the SAME utterance.)
  static func beats(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
    if lhs.text.isEmpty != rhs.text.isEmpty { return rhs.text.isEmpty }
    if lhs.isFinal != rhs.isFinal {
      // Exactly one side is final. A trusted final settles it outright; an
      // untrusted one has proved nothing the partial hasn't, so both drop
      // straight to the length tiebreak.
      let settled = lhs.isFinal ? lhs : rhs
      guard settled.averageConfidence >= trustedFinalConfidence else {
        return lhs.text.count > rhs.text.count
      }
      return lhs.isFinal
    }
    if abs(lhs.averageConfidence - rhs.averageConfidence) > confidenceEpsilon {
      return lhs.averageConfidence > rhs.averageConfidence
    }
    return lhs.text.count > rhs.text.count
  }

  /// The index of the leading candidate, or nil when there are none. Ties keep
  /// the earlier entry, so the caller controls the fallback by ordering its
  /// array (the recorder puts the app's own language first).
  static func bestIndex(of candidates: [Candidate]) -> Int? {
    guard !candidates.isEmpty else { return nil }
    var winner = 0
    for index in 1..<candidates.count where beats(candidates[index], candidates[winner]) {
      winner = index
    }
    return winner
  }

  static func best(_ candidates: [Candidate]) -> Candidate? {
    bestIndex(of: candidates).map { candidates[$0] }
  }

  // MARK: - Microphone level

  /// Anything quieter than this is silence as far as the waveform is concerned.
  /// -50 dBFS sits below room tone but well under speech, so a quiet room rests
  /// at 0 and a normal voice fills most of the range.
  static let silenceFloorDb = -50.0

  /// Raw buffer RMS (0…1 for normalized float samples) → a 0…1 bar height.
  ///
  /// Linear RMS is useless for a meter: conversational speech lands around
  /// 0.02–0.1 and would barely lift the bars off the floor. Converting to dBFS
  /// and mapping the top 50 dB onto 0…1 gives the logarithmic response the ear
  /// actually has. Non-finite and out-of-range input is clamped rather than
  /// trusted — it comes from an audio thread reading hardware.
  static func normalizedLevel(rms: Double) -> Double {
    guard rms.isFinite, rms > 0 else { return 0 }
    let decibels = 20 * log10(min(rms, 1))
    guard decibels > silenceFloorDb else { return 0 }
    return min(max((decibels - silenceFloorDb) / -silenceFloorDb, 0), 1)
  }
}
