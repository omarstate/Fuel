import Testing
import Foundation
@testable import Fuel

// The two decisions that make dual-language voice capture work, pinned away from
// the Speech framework: which recognizer's reading of the same audio wins, and
// how a raw buffer RMS becomes a waveform bar.
@Suite("Voice candidate scoring")
struct VoiceCandidateScoreTests {
  private typealias Candidate = VoiceCandidateScore.Candidate

  // MARK: - beats

  @Test("Anything beats a recognizer that heard nothing")
  func nonEmptyBeatsEmpty() {
    let heard = Candidate(text: "bench press 80 for 8")
    let mute = Candidate(text: "", averageConfidence: 0.9, isFinal: true)
    #expect(VoiceCandidateScore.beats(heard, mute))
    #expect(!VoiceCandidateScore.beats(mute, heard))
  }

  @Test("A final result outranks a partial one, even a longer partial")
  func finalBeatsPartial() {
    let settled = Candidate(text: "بيضتين", averageConfidence: 0.82, isFinal: true)
    let stillGoing = Candidate(text: "a much longer partial guess", averageConfidence: 0, isFinal: false)
    #expect(VoiceCandidateScore.beats(settled, stillGoing))
    #expect(!VoiceCandidateScore.beats(stillGoing, settled))
  }

  @Test("Between two finals, the more confident one wins")
  func confidenceDecidesBetweenFinals() {
    let confident = Candidate(text: "eggs", averageConfidence: 0.85, isFinal: true)
    let unsure = Candidate(text: "a longer but shakier reading", averageConfidence: 0.2, isFinal: true)
    #expect(VoiceCandidateScore.beats(confident, unsure))
    #expect(!VoiceCandidateScore.beats(unsure, confident))
  }

  @Test("Partials both report zero confidence, so the longer transcription wins")
  func lengthBreaksTheConfidenceTie() {
    let longer = Candidate(text: "تلات بيضات مسلوقين")
    let shorter = Candidate(text: "tell at")
    #expect(VoiceCandidateScore.beats(longer, shorter))
    #expect(!VoiceCandidateScore.beats(shorter, longer))
  }

  @Test("Confidences inside the epsilon count as a tie and fall through to length")
  func nearEqualConfidenceFallsThroughToLength() {
    let shorterButAHair = Candidate(text: "eggs", averageConfidence: 0.805, isFinal: true)
    let longer = Candidate(text: "three boiled eggs", averageConfidence: 0.8, isFinal: true)
    #expect(VoiceCandidateScore.beats(longer, shorterButAHair))
  }

  // MARK: - bestIndex

  @Test("No candidates means no winner")
  func bestIndexOfNothing() {
    #expect(VoiceCandidateScore.bestIndex(of: []) == nil)
  }

  @Test("A single recognizer wins by default — a device missing a language still logs")
  func bestIndexOfOne() {
    #expect(VoiceCandidateScore.bestIndex(of: [Candidate(text: "eggs")]) == 0)
  }

  @Test("The winner is picked across the whole array, not pairwise from the front")
  func bestIndexPicksTheLeader() {
    let candidates = [
      Candidate(text: "short"),
      Candidate(text: "the longest partial of the three"),
      Candidate(text: "middling one"),
    ]
    #expect(VoiceCandidateScore.bestIndex(of: candidates) == 1)
    #expect(VoiceCandidateScore.best(candidates)?.text == "the longest partial of the three")
  }

  @Test("A dead tie keeps the earlier entry — the recorder orders the app's language first")
  func tiesKeepTheFirstEntry() {
    let candidates = [Candidate(text: "same"), Candidate(text: "toss")]
    #expect(VoiceCandidateScore.bestIndex(of: candidates) == 0)
  }

  @Test("Two silent recognizers still resolve rather than crashing")
  func allEmpty() {
    #expect(VoiceCandidateScore.bestIndex(of: [Candidate(text: ""), Candidate(text: "")]) == 0)
  }

  // MARK: - normalizedLevel

  @Test("Full scale is 1 and anything at or below the silence floor is 0")
  func levelEndpoints() {
    #expect(VoiceCandidateScore.normalizedLevel(rms: 1) == 1)
    #expect(VoiceCandidateScore.normalizedLevel(rms: 0) == 0)
    // -50 dBFS is the floor itself, and -60 dBFS is below it.
    #expect(VoiceCandidateScore.normalizedLevel(rms: 0.00316) == 0)
    #expect(VoiceCandidateScore.normalizedLevel(rms: 0.001) == 0)
  }

  @Test("Out-of-range and non-finite input clamps into 0…1 instead of being trusted")
  func levelClamps() {
    #expect(VoiceCandidateScore.normalizedLevel(rms: 4) == 1)
    #expect(VoiceCandidateScore.normalizedLevel(rms: -1) == 0)
    // Non-finite readings are garbage from the audio thread, not loud audio —
    // they read as silence rather than pinning the meter.
    #expect(VoiceCandidateScore.normalizedLevel(rms: .nan) == 0)
    #expect(VoiceCandidateScore.normalizedLevel(rms: .infinity) == 0)
    #expect(VoiceCandidateScore.normalizedLevel(rms: -.infinity) == 0)
  }

  @Test("The response is logarithmic, so ordinary speech lifts the bars well off the floor")
  func levelIsLogarithmic() {
    // -20 dBFS — a normal speaking voice — must land near the middle, which a
    // linear meter (0.1) would never do.
    let speech = VoiceCandidateScore.normalizedLevel(rms: 0.1)
    #expect(speech > 0.55 && speech < 0.65)
    // Quiet room tone stays low but visible.
    let roomTone = VoiceCandidateScore.normalizedLevel(rms: 0.01)
    #expect(roomTone > 0.15 && roomTone < 0.25)
  }

  @Test("Louder audio always reads higher")
  func levelIsMonotonic() {
    let steps = [0.005, 0.02, 0.08, 0.3, 0.9]
    let levels = steps.map { VoiceCandidateScore.normalizedLevel(rms: $0) }
    #expect(levels == levels.sorted())
    #expect(levels.allSatisfy { $0 >= 0 && $0 <= 1 })
  }
}
