import Foundation

// PURE Foundation string helpers for voice SET logging — the workouts twin of
// VoiceAliases, which serves food.
//
// The two strip differently, and the difference is the whole point. Food is said
// as "تلات بيضات مسلوقين" — the amount comes FIRST, so `VoiceAliases.strippedPhrase`
// only peels leading tokens. A set is said as "بنش برس تمانين في تمانية" /
// "bench press 80 for 8" — the amounts TRAIL the exercise name, and peeling only
// the front would teach the catalog "بنش برس تمانين في تمانية" as an alias, which
// matches exactly one workout in history and never again.
//
// So this peels both ends: digits (Western or Arabic-Indic), spoken numbers
// including the tens people actually say for weights (تمانين, خمسين), weight
// units, and the rep/set connectives ("في", "for", "×", "reps", "سِت").
enum WorkoutVoiceAliases {
  /// Tokens that carry an amount, a unit or a connective — never part of an
  /// exercise's name. Lowercased; matched after punctuation is trimmed.
  private static let fillerWords: Set<String> = [
    // Egyptian Arabic units and tens — a weight is nearly always said in these
    "واحد", "واحده", "واحدة", "اتنين", "إتنين", "تنين",
    "تلات", "تلاته", "تلاتة", "ثلاث", "ثلاثة", "تلت", "ثلث",
    "اربع", "اربعه", "اربعة", "أربع", "أربعة",
    "خمس", "خمسه", "خمسة", "ست", "سته", "ستة",
    "سبع", "سبعه", "سبعة", "تمان", "تمانيه", "تمانية", "ثماني", "ثمانية",
    "تسع", "تسعه", "تسعة", "عشر", "عشره", "عشرة",
    "حداشر", "اتناشر", "تلاتاشر", "اربعتاشر", "خمستاشر",
    "عشرين", "تلاتين", "ثلاثين", "اربعين", "أربعين", "خمسين",
    "ستين", "سبعين", "تمانين", "ثمانين", "تسعين",
    "مية", "ميه", "مئة", "مائة", "نص", "نصف", "ربع",
    // Arabic weight units, rep/set words and connectives
    "كيلو", "كجم", "كيلوجرام", "جم", "جرام", "رطل",
    "في", "مرة", "مره", "مرات", "عدة", "عده", "عدات",
    "سِت", "سِتات", "ستات", "سيت", "سيتات", "مجموعة", "مجموعه",
    "كمان", "وبعدين", "بعدين", "بعد", "و", "ثم", "على", "ب", "بـ",
    // English numbers, including the tens a weight lands on
    "a", "an", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "fifteen", "twenty", "thirty", "forty",
    "fifty", "sixty", "seventy", "eighty", "ninety", "hundred",
    "half", "quarter", "couple", "some", "few",
    // English weight units, rep/set words and connectives
    "kg", "kgs", "kilo", "kilos", "kilogram", "kilograms",
    "lb", "lbs", "pound", "pounds",
    "rep", "reps", "set", "sets", "time", "times",
    "x", "×", "by", "for", "at", "of", "and", "then", "more", "another", "again",
  ]

  private static let separators = CharacterSet.whitespacesAndNewlines
  private static let trimmables = CharacterSet.whitespacesAndNewlines
    .union(CharacterSet(charactersIn: ".,،؛;:!?\"'()[]-–—×*"))

  /// True when the token is only an amount, a unit or a connective. A leading
  /// digit covers "80", "80kg" and the Arabic-Indic "٨٠" in one test; the
  /// و-prefix check covers the compound numbers Arabic writes as one word
  /// ("خمسة وتمانين" — eighty-five — arrives as two tokens, the second glued to
  /// its conjunction).
  private static func isFillerToken(_ token: String) -> Bool {
    guard let first = token.unicodeScalars.first else { return true }
    if CharacterSet.decimalDigits.contains(first) { return true }
    let lowered = token.lowercased()
    if fillerWords.contains(lowered) { return true }
    if lowered.hasPrefix("و"), fillerWords.contains(String(lowered.dropFirst())) { return true }
    return false
  }

  /// The exercise name inside a spoken set report, with the numbers peeled off
  /// BOTH ends: "بنش برس تمانين في تمانية" → "بنش برس", "bench press 80 for 8" →
  /// "bench press". Empty when nothing but an amount was said ("كمان سِت").
  ///
  /// Interior filler is left alone, so "hang clean and press" survives intact —
  /// only the ends of the phrase are amounts.
  static func exercisePhrase(spoken: String) -> String {
    var tokens = spoken
      .components(separatedBy: separators)
      .map { $0.trimmingCharacters(in: trimmables) }
      .filter { !$0.isEmpty }

    while let last = tokens.last, isFillerToken(last) {
      tokens.removeLast()
    }
    var index = 0
    while index < tokens.count, isFillerToken(tokens[index]) {
      index += 1
    }
    return tokens[index...].joined(separator: " ")
  }

  /// The alias to teach the catalog for a confirmed exercise, or `[]` when there
  /// is nothing worth learning: the phrase was only an amount, or it already
  /// says what the workout's own name says. Comparison goes through
  /// `VoiceAliases.sameText`, so case and Arabic diacritics don't create
  /// duplicate aliases.
  static func deriveAliases(spoken: String, name: String) -> [String] {
    let phrase = exercisePhrase(spoken: spoken)
    guard !phrase.isEmpty else { return [] }
    guard !VoiceAliases.sameText(phrase, name.trimmingCharacters(in: trimmables)) else { return [] }
    return [phrase]
  }
}
