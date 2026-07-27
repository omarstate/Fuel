import Testing
import Foundation
@testable import Fuel

// Round-trips LoggedMeal through plain coders (no supabase client) to prove the
// snake_case keys, ISO8601-with-fractional-seconds logged_at, and lenient macro
// decoding are fully self-contained.
@Suite("LoggedMeal coding")
struct LoggedMealCodingTests {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  private func decode(_ json: String) throws -> LoggedMeal {
    try decoder.decode(LoggedMeal.self, from: Data(json.utf8))
  }

  @Test("decode a DB row with snake_case keys and fractional-second timestamp")
  func decodeRow() throws {
    let json = #"""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "name": "Koshari",
      "meal_type": "lunch",
      "serving_size": "1 plate (450g)",
      "calories": 720,
      "protein": 22,
      "carbs": 120,
      "fat": 14,
      "logged_at": "2026-07-19T12:30:00.123Z",
      "catalog_meal_id": "33333333-3333-3333-3333-333333333333"
    }
    """#
    let meal = try decode(json)
    #expect(meal.name == "Koshari")
    #expect(meal.mealType == .lunch)
    #expect(meal.servingSize == "1 plate (450g)")
    #expect(meal.calories == 720)
    #expect(meal.fat == 14)
    #expect(meal.catalogMealId?.uuidString == "33333333-3333-3333-3333-333333333333")
    #expect(meal.userId.uuidString == "22222222-2222-2222-2222-222222222222")
  }

  @Test("nullable serving_size and catalog_meal_id decode to nil")
  func nullFields() throws {
    let json = #"""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "name": "Water",
      "meal_type": "snack",
      "serving_size": null,
      "calories": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0,
      "logged_at": "2026-07-19T12:30:00Z",
      "catalog_meal_id": null
    }
    """#
    let meal = try decode(json)
    #expect(meal.servingSize == nil)
    #expect(meal.catalogMealId == nil)
  }

  @Test("macros arriving as doubles are rounded to ints")
  func lenientMacros() throws {
    let json = #"""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "name": "AI estimate",
      "meal_type": "dinner",
      "calories": 719.6,
      "protein": 21.4,
      "carbs": 120.0,
      "fat": 13.5,
      "logged_at": "2026-07-19T12:30:00.500Z"
    }
    """#
    let meal = try decode(json)
    #expect(meal.calories == 720)  // 719.6 → 720
    #expect(meal.protein == 21)    // 21.4 → 21
    #expect(meal.carbs == 120)
    #expect(meal.fat == 14)        // 13.5 → 14 (round-half-away)
  }

  @Test("encode → decode round-trips identically")
  func roundTrip() throws {
    let original = LoggedMeal(
      id: UUID(),
      userId: UUID(),
      name: "Grilled chicken",
      mealType: .dinner,
      servingSize: nil,
      calories: 210,
      protein: 38,
      carbs: 0,
      fat: 6,
      loggedAt: TestCal.date(2026, 7, 19, 20, 15),
      catalogMealId: UUID()
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(LoggedMeal.self, from: data)
    #expect(decoded == original)
  }

  @Test("encoding uses snake_case keys and a string logged_at")
  func encodesSnakeCase() throws {
    let meal = LoggedMeal(userId: UUID(), name: "X", mealType: .breakfast, calories: 1, protein: 2, carbs: 3, fat: 4)
    let json = String(data: try encoder.encode(meal), encoding: .utf8)!
    #expect(json.contains("\"meal_type\""))
    #expect(json.contains("\"logged_at\""))
    #expect(json.contains("\"user_id\""))
    #expect(json.contains("\"serving_size\""))       // present, encoded as null
    #expect(json.contains("\"catalog_meal_id\""))
  }
}
