import Testing
import Foundation
@testable import Fuel

// Pins the difference between the two alias rules. Food is spoken amount-first
// ("تلات بيضات") so VoiceAliases peels only the FRONT; a set is spoken
// exercise-first ("بنش برس تمانين في تمانية") so the amounts trail — peeling only
// the front here would teach the catalog a phrase containing that day's weight,
// which would never match again.
@Suite("Workout voice aliases")
struct WorkoutVoiceAliasesTests {
  // MARK: - Arabic

  @Test("Trailing Egyptian weights and rep counts are stripped")
  func arabicTrailingAmounts() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "بنش برس تمانين في تمانية") == "بنش برس")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "سكوات مية في خمسة") == "سكوات")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "ديدليفت مية وعشرين كيلو في تلاتة") == "ديدليفت")
  }

  @Test("A compound number glued to its conjunction is still an amount")
  func arabicCompoundNumbers() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "بنش برس خمسة وتمانين في ستة") == "بنش برس")
  }

  @Test("Leading set words are stripped too")
  func arabicLeadingWords() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "كمان سِت بنش برس") == "بنش برس")
  }

  @Test("Arabic-Indic digits are stripped like Western ones")
  func arabicIndicDigits() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "بنش برس ٨٠ في ٨") == "بنش برس")
  }

  // MARK: - English

  @Test("Trailing English weights, units and rep counts are stripped")
  func englishTrailingAmounts() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "bench press 80 for 8") == "bench press")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "incline dumbbell press 30 kg x 12") == "incline dumbbell press")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "squat 100 by 5 reps") == "squat")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "pull ups twelve reps") == "pull ups")
  }

  @Test("Interior filler words survive — only the ends are amounts")
  func interiorWordsKept() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "hang clean and press 60 for 5") == "hang clean and press")
  }

  @Test("A phrase with no amounts is returned untouched")
  func noAmounts() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "romanian deadlift") == "romanian deadlift")
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "عقلة") == "عقلة")
  }

  @Test("Punctuation around the phrase is trimmed")
  func punctuation() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "  bench press, 80 × 8.  ") == "bench press")
  }

  @Test("A phrase that is only an amount collapses to nothing")
  func onlyAmounts() {
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "كمان سِت").isEmpty)
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "80 for 8").isEmpty)
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "   ").isEmpty)
    #expect(WorkoutVoiceAliases.exercisePhrase(spoken: "").isEmpty)
  }

  // MARK: - deriveAliases

  @Test("An alias is taught only when it says something the name doesn't")
  func derivesTheSpokenPhrase() {
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "بنش برس تمانين في تمانية", name: "Bench Press") == ["بنش برس"])
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "lat pulldown 60 for 12", name: "Cable Lat Pulldown") == ["lat pulldown"])
  }

  @Test("An alias equal to the workout's own name is dropped")
  func equalToNameDropped() {
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "bench press 80 for 8", name: "Bench Press").isEmpty)
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "Bench Press", name: "bench press").isEmpty)
    // Diacritics must not create a duplicate alias (shared with VoiceAliases.sameText).
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "بَنش برس", name: "بنش برس").isEmpty)
  }

  @Test("A phrase that was only an amount teaches nothing")
  func nothingToLearn() {
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "كمان سِت", name: "Bench Press").isEmpty)
    #expect(WorkoutVoiceAliases.deriveAliases(spoken: "", name: "Bench Press").isEmpty)
  }
}
