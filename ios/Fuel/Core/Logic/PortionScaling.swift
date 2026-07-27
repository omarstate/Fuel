import Foundation

// Scales a catalog meal's macros by a serving multiplier for the add-to-log
// flow. The personal log stores integer macros, so every scaled value rounds to
// the nearest Int (mirrors the web's `Math.round(value * factor)`). Pure
// Foundation so the rounding is unit-tested.
enum PortionScaling {
  struct Macros: Equatable, Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
  }

  /// One scaled, rounded macro value.
  static func scaledInt(_ value: Double, factor: Double) -> Int {
    Int((value * factor).rounded())
  }

  static func macros(
    calories: Double,
    protein: Double,
    carbs: Double,
    fat: Double,
    factor: Double
  ) -> Macros {
    Macros(
      calories: scaledInt(calories, factor: factor),
      protein: scaledInt(protein, factor: factor),
      carbs: scaledInt(carbs, factor: factor),
      fat: scaledInt(fat, factor: factor)
    )
  }

  /// A short human factor label: whole numbers stay whole ("2"), halves keep one
  /// decimal ("1.5"). Used to annotate the logged serving size.
  static func factorLabel(_ factor: Double) -> String {
    if factor.rounded() == factor {
      return String(Int(factor))
    }
    return String(format: "%.1f", factor)
  }
}
