import Foundation

// PURE Foundation port of the meal-type pieces of src/app/nutrition/types.ts
// (`MealType`, `mealTypeLabel`, `suggestedMealType`, `MEAL_TYPE_ORDER`).
// Defined here because MealType is shared across the whole app (log rows,
// sections, the manual-add sheet, the meal-log repository).

enum MealType: String, Codable, CaseIterable, Sendable, Identifiable {
  case breakfast
  case lunch
  case dinner
  case snack

  var id: String { rawValue }

  /// Display label (matches `mealTypeLabel` in the TS). A localized String (not
  /// LocalizedStringKey) so this file stays SwiftUI-free per the Core/Logic rule.
  var label: String {
    switch self {
    case .breakfast: return String(localized: "Breakfast")
    case .lunch: return String(localized: "Lunch")
    case .dinner: return String(localized: "Dinner")
    case .snack: return String(localized: "Snack")
    }
  }
}

enum MealTypeSuggestion {
  /// `MEAL_TYPE_ORDER` — the canonical section order.
  static let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]

  /// Smart default section by local time of day.
  ///   breakfast 4–11h · lunch 11–16 · dinner 16–22 · else snack.
  static func suggested(_ date: Date = Date(), calendar: Calendar = .current) -> MealType {
    let h = calendar.component(.hour, from: date)
    if h >= 4 && h < 11 { return .breakfast }
    if h >= 11 && h < 16 { return .lunch }
    if h >= 16 && h < 22 { return .dinner }
    return .snack
  }
}
