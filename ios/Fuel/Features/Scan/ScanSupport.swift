import Foundation

// Small shared helpers for the M5 scan flows.

/// Identifiable wrapper so a `Review` can drive `.sheet(item:)` for the
/// LabelReviewSheet from the photo flow.
struct LabelReviewContext: Identifiable {
  let id = UUID()
  let review: Review
  let brand: String?

  init(review: Review, brand: String? = nil) {
    self.review = review
    self.brand = brand
  }
}

/// Barcode code validation matching the backend (`^\d{8,14}$`). Normalizes
/// Eastern Arabic-Indic digits to ASCII first so a code typed on an Arabic
/// numeric keyboard still validates and sends correctly.
enum BarcodeCode {
  /// ASCII-digit form of the input (Arabic-Indic digits mapped, everything else
  /// dropped).
  static func normalized(_ raw: String) -> String {
    var out = ""
    for scalar in raw.unicodeScalars {
      switch scalar.value {
      case 0x30...0x39: out.unicodeScalars.append(scalar)                              // 0–9
      case 0x0660...0x0669: out.append(Character(UnicodeScalar(scalar.value - 0x0660 + 0x30)!)) // ٠–٩
      case 0x06F0...0x06F9: out.append(Character(UnicodeScalar(scalar.value - 0x06F0 + 0x30)!)) // ۰–۹
      default: break
      }
    }
    return out
  }

  static func isValid(_ raw: String) -> Bool {
    let n = normalized(raw)
    return (8...14).contains(n.count)
  }
}
