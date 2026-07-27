import Foundation

// Locale-aware numeric parsing. Never use `Double(string)` for user input —
// Arabic (ar_EG) uses different decimal separators and Eastern Arabic-Indic
// digits, which `Double.init` rejects.
enum NumberParsing {
  private static let formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.usesGroupingSeparator = false
    return f
  }()

  /// Parse a decimal in the current locale, falling back to a POSIX parse so
  /// "70.5" typed on an Arabic keyboard-less field still works.
  static func double(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let number = formatter.number(from: trimmed) {
      return number.doubleValue
    }
    // Fallback: normalize a comma decimal separator and try POSIX.
    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    return Double(normalized)
  }

  static func int(_ text: String) -> Int? {
    guard let value = double(text) else { return nil }
    return Int(value.rounded())
  }
}
