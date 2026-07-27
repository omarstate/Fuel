import Testing
import Foundation
@testable import Fuel

// Hand-computed against suggestedMealType in src/app/nutrition/types.ts:
// breakfast 4–11h · lunch 11–16 · dinner 16–22 · else snack.
@Suite("MealType suggestion")
struct MealTypeSuggestionTests {
  private func at(_ hour: Int) -> MealType {
    MealTypeSuggestion.suggested(TestCal.date(2026, 7, 19, hour), calendar: TestCal.utc)
  }

  @Test("hour boundaries")
  func boundaries() {
    #expect(at(3) == .snack)      // before 4
    #expect(at(4) == .breakfast)  // 4 inclusive
    #expect(at(10) == .breakfast)
    #expect(at(11) == .lunch)     // 11 flips to lunch
    #expect(at(15) == .lunch)
    #expect(at(16) == .dinner)    // 16 flips to dinner
    #expect(at(21) == .dinner)
    #expect(at(22) == .snack)     // 22 flips to snack
    #expect(at(0) == .snack)
    #expect(at(23) == .snack)
  }

  @Test("order matches MEAL_TYPE_ORDER")
  func order() {
    #expect(MealTypeSuggestion.order == [.breakfast, .lunch, .dinner, .snack])
    #expect(MealType.allCases == [.breakfast, .lunch, .dinner, .snack])
  }
}
