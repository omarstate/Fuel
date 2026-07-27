import Foundation

// PURE Foundation port of frontend/src/app-editorial/label-portion.ts.
//
// A label states macros on some basis (per 100 g/ml or per serving); the user
// tells us how much they ate and we scale. Kept separate from the review UI so
// this — the error-prone bit — is independently unit-tested and has no SwiftUI
// dependency. The barcode lookup (`BarcodeProduct`) and photo extraction
// (`ExtractedLabel`) both satisfy `LabelSource`, so the review/scale flow is
// shared between the two M5 features.
//
// Semantics mirror the TS exactly (grams-authoritative sync, identical rounding
// and default-portion rules). The one deliberate enhancement over the JS source
// is `parseServingGrams`: it additionally normalizes Eastern Arabic-Indic digits
// (٠–٩ / ۰–۹) to ASCII before matching, because the app is Egypt-first and JS's
// `\d` is ASCII-only. Numeric strings are parsed locale-aware via NumberParsing
// (a superset of JS `Number`) and formatted POSIX-style so they round-trip.

enum LabelBasis: String, Codable, Sendable, Equatable {
  case per100g = "per_100g"
  case perServing = "per_serving"
}

enum LabelConfidence: String, Codable, Sendable, Equatable {
  case high, medium, low

  var label: String {
    switch self {
    case .high: return String(localized: "High")
    case .medium: return String(localized: "Medium")
    case .low: return String(localized: "Low")
    }
  }
}

/// The four macro keys, in display order. Mirrors the TS `MACROS`.
enum LabelMacro: String, CaseIterable, Sendable {
  case calories, protein, carbs, fat
}

/// The subset of fields `toReview` needs. Both `ExtractedLabel` and
/// `BarcodeProduct` conform, so the review/scale UI is shared. (`LabelLike`.)
protocol LabelSource {
  var name: String? { get }
  var basis: LabelBasis { get }
  var servingSize: String { get }
  var servingGrams: Double? { get }
  var calories: Double { get }
  var protein: Double { get }
  var carbs: Double { get }
  var fat: Double { get }
  var confidence: LabelConfidence? { get }
  var note: String { get }
  var ok: Bool { get }
}

/// Editable review state. `base` holds the values as read off the label (on its
/// own basis) so the totals can be rescaled when the portion changes; the string
/// fields are the final numbers that actually get logged. (`Review`.)
struct Review: Equatable, Sendable {
  var name: String
  var basis: LabelBasis
  var servingSize: String
  /// grams (or ml) in one printed serving, retained from the label.
  var servingGrams: Double?
  var base: Base
  /// grams eaten — a string so the input stays controlled.
  var grams: String
  /// number of servings — derived from grams for display when both apply.
  var servings: String
  var calories: String
  var protein: String
  var carbs: String
  var fat: String
  var confidence: LabelConfidence?
  var note: String
  var ok: Bool

  /// The four macro totals as read off the label, on the label's basis.
  struct Base: Equatable, Sendable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    subscript(_ macro: LabelMacro) -> Double {
      switch macro {
      case .calories: return calories
      case .protein: return protein
      case .carbs: return carbs
      case .fat: return fat
      }
    }
  }

  /// The current (edited) string value for a macro field.
  func value(for macro: LabelMacro) -> String {
    switch macro {
    case .calories: return calories
    case .protein: return protein
    case .carbs: return carbs
    case .fat: return fat
    }
  }

  mutating func setValue(_ value: String, for macro: LabelMacro) {
    switch macro {
    case .calories: calories = value
    case .protein: protein = value
    case .carbs: carbs = value
    case .fat: fat = value
    }
  }
}

enum LabelPortion {
  // MARK: - Number helpers (mirror JS Number()/String()/round2)

  /// `Number(x) || 0` — locale-aware parse (superset of JS Number), 0 on fail.
  private static func number(_ text: String) -> Double {
    NumberParsing.double(text) ?? 0
  }

  /// Whether a string parses to a finite number and isn't blank — mirrors
  /// `patch !== "" && Number.isFinite(Number(patch))`.
  private static func isFiniteNonEmpty(_ text: String) -> Bool {
    !text.trimmingCharacters(in: .whitespaces).isEmpty && NumberParsing.double(text) != nil
  }

  /// `Math.round(n * 100) / 100`.
  private static func round2(_ n: Double) -> Double { (n * 100).rounded() / 100 }

  /// POSIX-style `String(number)`: whole numbers drop the decimal, otherwise up
  /// to two trailing-zero-trimmed decimals ("1.5", "2", "3.33").
  static func numberString(_ value: Double) -> String {
    if value.rounded() == value { return String(Int(value)) }
    var s = String(format: "%.2f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
  }

  // MARK: - Core scaling

  /// Grams that one portion "unit" represents: 100 for per-100g labels, one
  /// serving's grams for per-serving labels (nil when that isn't printed).
  static func gramsPerUnit(basis: LabelBasis, servingGrams: Double?) -> Double? {
    basis == .per100g ? 100 : servingGrams
  }

  static func gramsPerUnit(_ r: Review) -> Double? {
    gramsPerUnit(basis: r.basis, servingGrams: r.servingGrams)
  }

  static func canUseGrams(_ r: Review) -> Bool { gramsPerUnit(r) != nil }

  static func portionFactor(_ r: Review) -> Double {
    if let per = gramsPerUnit(r) {
      return number(r.grams) / per
    }
    return number(r.servings)
  }

  static func scaled(_ base: Review.Base, factor: Double) -> (calories: String, protein: String, carbs: String, fat: String) {
    (
      calories: String(Int((base.calories * factor).rounded())),
      protein: String(Int((base.protein * factor).rounded())),
      carbs: String(Int((base.carbs * factor).rounded())),
      fat: String(Int((base.fat * factor).rounded()))
    )
  }

  /// Apply a portion edit: keep grams and servings in sync whenever the label
  /// printed a serving size (grams is authoritative; servings is derived), then
  /// rescale the macro totals from `base`.
  static func applyPortion(_ prev: Review, grams: String? = nil, servings: String? = nil) -> Review {
    var next = prev
    if let grams { next.grams = grams }
    if let servings { next.servings = servings }

    if let sg = prev.servingGrams, sg > 0 {
      if let grams {
        next.servings = isFiniteNonEmpty(grams) ? numberString(round2(number(grams) / sg)) : ""
      } else if let servings {
        next.grams = isFiniteNonEmpty(servings) ? String(Int((number(servings) * sg).rounded())) : ""
      }
    }

    let s = scaled(next.base, factor: portionFactor(next))
    next.calories = s.calories
    next.protein = s.protein
    next.carbs = s.carbs
    next.fat = s.fat
    return next
  }

  /// Build the initial review from a label. Default portion:
  ///  - per_100g → grams = printed serving size, else 100.
  ///  - per_serving with a known serving size → one whole serving in grams.
  ///  - per_serving without → one serving, no grams control.
  static func toReview(_ e: LabelSource) -> Review {
    let base = Review.Base(calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat)

    let grams: String
    if e.basis == .per100g {
      grams = numberString(e.servingGrams ?? 100)
    } else {
      grams = e.servingGrams != nil ? numberString(e.servingGrams!) : ""
    }
    let servings = "1"

    var review = Review(
      name: e.name ?? "",
      basis: e.basis,
      servingSize: e.servingSize,
      servingGrams: e.servingGrams,
      base: base,
      grams: grams,
      servings: servings,
      calories: "0",
      protein: "0",
      carbs: "0",
      fat: "0",
      confidence: e.confidence,
      note: e.note,
      ok: e.ok
    )
    let s = scaled(base, factor: portionFactor(review))
    review.calories = s.calories
    review.protein = s.protein
    review.carbs = s.carbs
    review.fat = s.fat
    return review
  }

  /// The `serving_size` text stored on the logged row: the grams eaten when we
  /// have a grams basis, otherwise a servings description; falls back to the
  /// printed serving size when the portion field is empty.
  static func eatenText(_ r: Review) -> String {
    if canUseGrams(r) {
      let g = r.grams.trimmingCharacters(in: .whitespaces)
      return !g.isEmpty ? "\(g) g" : r.servingSize
    }
    let s = r.servings.trimmingCharacters(in: .whitespaces)
    if s.isEmpty { return r.servingSize }
    if !r.servingSize.isEmpty { return "\(s) × \(r.servingSize)" }
    return "\(s) serving\(s == "1" ? "" : "s")"
  }

  /// Per-100g-normalized values (with a serving-size string) for the shared
  /// catalog save. Recovers the label's per-basis numbers from the current
  /// edited fields, then normalizes to per 100 g when a grams basis exists;
  /// otherwise saves the per-serving values as-is. Returns nil (skip the save)
  /// when the recovered calories are non-positive.
  struct CatalogBase: Equatable, Sendable {
    let servingSize: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
  }

  static func toCatalogBase(_ r: Review) -> CatalogBase? {
    let factor = portionFactor(r)
    let per = gramsPerUnit(r)
    func recover(_ macro: LabelMacro) -> Double {
      factor > 0 ? number(r.value(for: macro)) / factor : r.base[macro]
    }
    let perBasis = Review.Base(
      calories: recover(.calories),
      protein: recover(.protein),
      carbs: recover(.carbs),
      fat: recover(.fat)
    )

    if let per {
      let norm = CatalogBase(
        servingSize: "100 g",
        calories: Int((perBasis.calories * 100 / per).rounded()),
        protein: Int((perBasis.protein * 100 / per).rounded()),
        carbs: Int((perBasis.carbs * 100 / per).rounded()),
        fat: Int((perBasis.fat * 100 / per).rounded())
      )
      return norm.calories <= 0 ? nil : norm
    }

    let trimmed = r.servingSize.trimmingCharacters(in: .whitespaces)
    let rounded = CatalogBase(
      servingSize: trimmed.isEmpty ? "1 serving" : trimmed,
      calories: Int(perBasis.calories.rounded()),
      protein: Int(perBasis.protein.rounded()),
      carbs: Int(perBasis.carbs.rounded()),
      fat: Int(perBasis.fat.rounded())
    )
    return rounded.calories <= 0 ? nil : rounded
  }

  // MARK: - Serving-size parsing

  /// Pull the grams (or ml) out of a `serving_size` string. Prefers a
  /// parenthesized quantity ("1 cup (240 ml)" → 240), else the first
  /// number+unit. kg/l scale ×1000. Returns nil when nothing usable is found.
  ///
  /// Enhancement over the JS source: Eastern Arabic-Indic digits are normalized
  /// to ASCII first so "٢٥٠ جم" parses to 250.
  static func parseServingGrams(_ text: String?) -> Double? {
    guard let raw = text, !raw.isEmpty else { return nil }
    let normalized = normalizeDigits(raw)

    // The unit must not be the start of a longer word ("1 large" is not a litre).
    let pattern = #"(\d+(?:[.,]\d+)?)\s*(kg|كجم|جرام|جم|grams?|gm|ml|مل|g|l)(?![a-z\x{0600}-\x{06FF}])"#
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }

    let paren = firstParenthesized(normalized)
    let chunks = paren != nil ? [paren!, normalized] : [normalized]
    for chunk in chunks {
      let range = NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)
      guard let m = re.firstMatch(in: chunk, options: [], range: range),
            let numRange = Range(m.range(at: 1), in: chunk),
            let unitRange = Range(m.range(at: 2), in: chunk) else { continue }
      let numText = String(chunk[numRange]).replacingOccurrences(of: ",", with: ".")
      guard let num = Double(numText), num.isFinite else { continue }
      let unit = String(chunk[unitRange]).lowercased()
      let grams = num * (unit == "kg" || unit == "كجم" || unit == "l" ? 1000 : 1)
      if grams > 0 { return grams }
    }
    return nil
  }

  /// The contents of the first `(...)` group, or nil.
  private static func firstParenthesized(_ text: String) -> String? {
    guard let open = text.firstIndex(of: "("),
          let close = text[text.index(after: open)...].firstIndex(of: ")") else { return nil }
    return String(text[text.index(after: open)..<close])
  }

  /// Map Eastern Arabic-Indic (٠–٩) and Extended Arabic-Indic (۰–۹) digits and
  /// the Arabic decimal separator (٫) to their ASCII equivalents. Unit letters
  /// are left untouched.
  private static func normalizeDigits(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    for scalar in text.unicodeScalars {
      switch scalar.value {
      case 0x0660...0x0669: out.append(Character(UnicodeScalar(scalar.value - 0x0660 + 0x30)!)) // ٠–٩
      case 0x06F0...0x06F9: out.append(Character(UnicodeScalar(scalar.value - 0x06F0 + 0x30)!)) // ۰–۹
      case 0x066B: out.append(".") // Arabic decimal separator ٫
      default: out.unicodeScalars.append(scalar)
      }
    }
    return out
  }

  // MARK: - Manual entry

  /// A blank per-serving review for hand entry when no label data exists
  /// (product not found / unreadable photo). One serving, editable macros.
  static func manualReview(name: String = "") -> Review {
    toReview(BlankLabel(name: name.isEmpty ? nil : name))
  }

  private struct BlankLabel: LabelSource {
    let name: String?
    let basis: LabelBasis = .perServing
    let servingSize: String = ""
    let servingGrams: Double? = nil
    let calories: Double = 0
    let protein: Double = 0
    let carbs: Double = 0
    let fat: Double = 0
    let confidence: LabelConfidence? = nil
    let note: String = ""
    let ok: Bool = true
  }
}
