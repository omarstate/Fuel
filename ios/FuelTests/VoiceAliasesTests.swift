import Testing
import Foundation
@testable import Fuel

// Pins the alias-learning rule for voice logging: an alias is what the user SAID
// with the amount stripped off, and it's only worth saving when it adds something
// the catalog name doesn't already say. Quantities belong to a single log entry,
// never to a food's name — so "تلات بيضات مسلوقين" teaches "بيضات مسلوقين" and
// "3 boiled eggs" teaches "boiled eggs", while anything that collapses to nothing
// (or just repeats the meal name) teaches nothing.
@Suite("Voice aliases")
struct VoiceAliasesTests {
  // MARK: - Arabic

  @Test("Egyptian Arabic quantity words are stripped")
  func arabicQuantityWords() {
    #expect(VoiceAliases.deriveAliases(spoken: "تلات بيضات مسلوقين", name: "Boiled Eggs") == ["بيضات مسلوقين"])
    #expect(VoiceAliases.deriveAliases(spoken: "اتنين طعمية", name: "Falafel") == ["طعمية"])
    #expect(VoiceAliases.deriveAliases(spoken: "نص رغيف عيش بلدي", name: "Baladi Bread") == ["رغيف عيش بلدي"])
    #expect(VoiceAliases.deriveAliases(spoken: "خمس حبات تمر", name: "Dates") == ["حبات تمر"])
  }

  @Test("Arabic-Indic digits are stripped like Western ones")
  func arabicIndicDigits() {
    #expect(VoiceAliases.deriveAliases(spoken: "٣ بيضات", name: "Boiled Eggs") == ["بيضات"])
  }

  @Test("Arabic diacritics don't defeat the equal-to-name check")
  func arabicDiacritics() {
    #expect(VoiceAliases.deriveAliases(spoken: "بَيضات", name: "بيضات").isEmpty)
  }

  // MARK: - English

  @Test("English quantity words and digits are stripped")
  func englishQuantities() {
    #expect(VoiceAliases.deriveAliases(spoken: "3 boiled eggs", name: "Hard-Boiled Eggs") == ["boiled eggs"])
    #expect(VoiceAliases.deriveAliases(spoken: "two slices of toast", name: "Toast") == ["slices of toast"])
    #expect(VoiceAliases.deriveAliases(spoken: "200ml skimmed milk", name: "Milk") == ["skimmed milk"])
    #expect(VoiceAliases.deriveAliases(spoken: "a foul sandwich", name: "Foul Medames") == ["foul sandwich"])
  }

  @Test("Punctuation around the phrase is trimmed")
  func punctuation() {
    #expect(VoiceAliases.deriveAliases(spoken: "  2 mango juice,  ", name: "Orange Juice") == ["mango juice"])
  }

  // MARK: - Nothing worth learning

  @Test("An alias equal to the meal name is dropped")
  func equalToNameDropped() {
    #expect(VoiceAliases.deriveAliases(spoken: "Boiled Eggs", name: "Boiled Eggs").isEmpty)
    #expect(VoiceAliases.deriveAliases(spoken: "3 boiled eggs", name: "Boiled eggs").isEmpty)
  }

  @Test("A phrase that is only an amount is dropped")
  func emptyDropped() {
    #expect(VoiceAliases.deriveAliases(spoken: "تلاتة", name: "Boiled Eggs").isEmpty)
    #expect(VoiceAliases.deriveAliases(spoken: "3", name: "Boiled Eggs").isEmpty)
    #expect(VoiceAliases.deriveAliases(spoken: "   ", name: "Boiled Eggs").isEmpty)
    #expect(VoiceAliases.deriveAliases(spoken: "", name: "Boiled Eggs").isEmpty)
  }

  @Test("Non-quantity leading words are preserved")
  func keepsRealWords() {
    #expect(VoiceAliases.strippedPhrase("grilled chicken breast") == "grilled chicken breast")
    #expect(VoiceAliases.strippedPhrase("فراخ مشوية") == "فراخ مشوية")
  }

  // MARK: - Serving annotation

  @Test("Serving annotation reuses the shared factor label")
  func servingAnnotation() {
    #expect(VoiceAliases.annotatedServingSize(factor: 3, base: "1 egg (50g)") == "3× 1 egg (50g)")
    #expect(VoiceAliases.annotatedServingSize(factor: 1, base: "1 egg (50g)") == "1 egg (50g)")
    #expect(VoiceAliases.annotatedServingSize(factor: 1.5, base: "1 plate") == "1.5× 1 plate")
    #expect(VoiceAliases.annotatedServingSize(factor: 1, base: nil) == nil)
    #expect(VoiceAliases.annotatedServingSize(factor: 1, base: "   ") == nil)
    // No base serving text and a scaled portion → a bare serving count.
    #expect(VoiceAliases.annotatedServingSize(factor: 2, base: nil)?.contains("2") == true)
  }
}
