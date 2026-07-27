import Foundation

// Pure Foundation string helpers for voice logging (no SwiftUI, no Speech, no
// Supabase) so they are unit-tested.
//
// `deriveAliases` turns what the user SAID into an alias worth teaching the
// catalog. Catalog names are English; Egyptian Arabic speech is how people
// actually log, so "تلات بيضات مسلوقين" should teach "بيضات مسلوقين" against
// "Boiled Eggs". Quantities are stripped because they belong to one log entry,
// not to the food's name, and an alias that collapses to nothing (or that just
// repeats the meal's own name) is dropped rather than saved.
enum VoiceAliases {
  /// Leading words that only express an amount, in Egyptian Arabic and English.
  /// Egyptian numbers appear in both the standalone and construct forms people
  /// actually say (تلاتة / تلات), with and without hamza.
  private static let quantityWords: Set<String> = [
    // Egyptian Arabic numbers
    "واحد", "واحده", "واحدة", "اتنين", "إتنين", "تنين",
    "تلات", "تلاته", "تلاتة", "ثلاث", "ثلاثة", "تلت", "ثلث",
    "اربع", "اربعه", "اربعة", "أربع", "أربعة",
    "خمس", "خمسه", "خمسة", "ست", "سته", "ستة",
    "سبع", "سبعه", "سبعة", "تمان", "تمانيه", "تمانية", "ثماني", "ثمانية",
    "تسع", "تسعه", "تسعة", "عشر", "عشره", "عشرة",
    "نص", "نصف", "ربع", "كام", "شوية", "شويه",
    // English numbers and vague amounts
    "a", "an", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "twenty", "half", "quarter", "couple",
    "some", "few", "of",
  ]

  private static let separators = CharacterSet.whitespacesAndNewlines
  private static let trimmables = CharacterSet.whitespacesAndNewlines
    .union(CharacterSet(charactersIn: ".,،؛;:!?\"'()[]-–—×"))

  /// True when the token carries no meaning beyond an amount: a leading digit
  /// (Western or Arabic-Indic — covers "3", "200ml", "٣") or a quantity word.
  private static func isQuantityToken(_ token: String) -> Bool {
    guard let first = token.unicodeScalars.first else { return true }
    if CharacterSet.decimalDigits.contains(first) { return true }
    return quantityWords.contains(token.lowercased())
  }

  /// The spoken phrase with its leading quantity words/digits removed, whitespace
  /// collapsed. Empty when nothing but an amount was said.
  static func strippedPhrase(_ spoken: String) -> String {
    let tokens = spoken
      .components(separatedBy: separators)
      .map { $0.trimmingCharacters(in: trimmables) }
      .filter { !$0.isEmpty }

    var index = 0
    while index < tokens.count, isQuantityToken(tokens[index]) {
      index += 1
    }
    return tokens[index...].joined(separator: " ")
  }

  /// Case- and diacritic-insensitive equality, so "Boiled Eggs" == "boiled eggs"
  /// and "بيضات" == "بَيضات".
  static func sameText(_ lhs: String, _ rhs: String) -> Bool {
    lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
  }

  /// The alias to teach the catalog for a confirmed item, or `[]` when there is
  /// nothing worth learning: the phrase was only an amount, or it already says
  /// the same thing as the meal's name.
  static func deriveAliases(spoken: String, name: String) -> [String] {
    let phrase = strippedPhrase(spoken)
    guard !phrase.isEmpty else { return [] }
    guard !sameText(phrase, name.trimmingCharacters(in: trimmables)) else { return [] }
    return [phrase]
  }

  /// The serving text stored on a log entry for a scaled catalog meal:
  /// "3× 1 egg (50g)" at 3×, the bare serving size at 1×, "1.5 servings" when the
  /// meal has no serving text. Multiplier formatting is `PortionScaling.factorLabel`
  /// so every surface annotates portions identically.
  static func annotatedServingSize(factor: Double, base: String?) -> String? {
    let trimmed = base?.trimmingCharacters(in: .whitespacesAndNewlines)
    let isWhole = factor == 1
    if let trimmed, !trimmed.isEmpty {
      return isWhole ? trimmed : "\(PortionScaling.factorLabel(factor))× \(trimmed)"
    }
    return isWhole ? nil : String(localized: "\(PortionScaling.factorLabel(factor)) servings")
  }
}
