import Foundation

// The macros LEFT for today (target − consumed), clamped into the ranges the
// suggest endpoint validates, plus the bucketed cache key the Coach uses to
// avoid re-hitting the endpoint on every nearby state. Pure Foundation — the
// clamp and bucket math are unit-tested.
struct RemainingMacros: Encodable, Equatable, Sendable {
  let calories: Int
  let protein: Int
  let carbs: Int
  let fat: Int

  // Server-validated ceilings (floor is 0 for all).
  static let maxCalories = 8000
  static let maxProtein = 600
  static let maxCarbs = 1000
  static let maxFat = 400

  init(calories: Int, protein: Int, carbs: Int, fat: Int) {
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
  }

  /// target − consumed, floored at 0 and capped at each ceiling.
  static func clamp(targets: Targets, totals: LoggedMeal.Totals) -> RemainingMacros {
    RemainingMacros(
      calories: clampValue(targets.calories - totals.calories, max: maxCalories),
      protein: clampValue(targets.protein - totals.protein, max: maxProtein),
      carbs: clampValue(targets.carbs - totals.carbs, max: maxCarbs),
      fat: clampValue(targets.fat - totals.fat, max: maxFat)
    )
  }

  static func clampValue(_ value: Int, max cap: Int) -> Int {
    Swift.min(Swift.max(value, 0), cap)
  }

  /// 10-minute cache bucket so many nearby remaining states share one answer.
  /// Matches the web: floor(cal/100)|floor(protein/10)|floor(carbs/15)|floor(fat/10)|lang.
  /// Values are non-negative after clamp, so integer division == floor.
  func bucketKey(lang: String) -> String {
    "\(calories / 100)|\(protein / 10)|\(carbs / 15)|\(fat / 10)|\(lang)"
  }
}
