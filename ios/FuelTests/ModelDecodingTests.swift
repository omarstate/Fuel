import Testing
import Foundation
@testable import Fuel

// Decoding fixtures shaped like real API responses (camelCase, ISO8601 dates,
// nullable fields, macroRanges as [min,max] arrays).
@Suite("Model decoding")
struct ModelDecodingTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  @Test("Me")
  func me() throws {
    let me = try decode(Me.self, #"{"id":"u_123","email":"sama@ecs-co.com","isAdmin":true}"#)
    #expect(me.id == "u_123")
    #expect(me.email == "sama@ecs-co.com")
    #expect(me.isAdmin == true)
  }

  @Test("Profile with fractional-second dates")
  func profile() throws {
    let json = #"""
    {
      "userId": "u_123",
      "sex": "female",
      "age": 29,
      "heightCm": 168,
      "weightKg": 63.5,
      "goalWeightKg": 60,
      "activityLevel": "moderate",
      "pace": "standard",
      "targetCalories": 1780,
      "targetProtein": 114,
      "targetCarbs": 190,
      "targetFat": 49,
      "onboardedAt": "2026-07-01T09:30:00.123Z",
      "updatedAt": "2026-07-19T12:00:00Z"
    }
    """#
    let profile = try decode(Profile.self, json)
    #expect(profile.sex == .female)
    #expect(profile.age == 29)
    #expect(profile.weightKg == 63.5)
    #expect(profile.activityLevel == .moderate)
    #expect(profile.pace == .standard)
    #expect(profile.targets == Targets(calories: 1780, protein: 114, carbs: 190, fat: 49))
    #expect(profile.onboardedAt != nil)          // parsed with fractional seconds
    #expect(profile.updatedAt != nil)            // parsed without fractional seconds
  }

  @Test("null profile decodes to nil")
  func nullProfile() throws {
    let profile = try decode(Profile?.self, "null")
    #expect(profile == nil)
  }

  @Test("CatalogMeal with macroRanges and null category")
  func catalogMealEstimate() throws {
    let json = #"""
    {
      "id": "m_1",
      "name": "Koshari",
      "description": "Rice, lentils, pasta, chickpeas",
      "servingSize": "1 plate (450g)",
      "calories": 720,
      "protein": 22,
      "carbs": 120,
      "fat": 14,
      "category": null,
      "createdBy": null,
      "createdAt": "2026-07-10T18:22:05Z",
      "aiSource": "estimate",
      "sourceUrl": null,
      "macroRanges": {
        "calories": [640, 800],
        "protein": [18, 26],
        "carbs": [110, 130],
        "fat": [10, 18]
      }
    }
    """#
    let meal = try decode(CatalogMeal.self, json)
    #expect(meal.name == "Koshari")
    #expect(meal.category == nil)
    #expect(meal.createdBy == nil)
    #expect(meal.aiSource == .estimate)
    #expect(meal.macroRanges?.calories.min == 640)
    #expect(meal.macroRanges?.calories.max == 800)
    #expect(meal.macroRanges?.fat.max == 18)
  }

  @Test("CatalogMeal official with category, no macroRanges")
  func catalogMealOfficial() throws {
    let json = #"""
    {
      "id": "m_2",
      "name": "Grilled chicken breast",
      "calories": 165,
      "protein": 31,
      "carbs": 0,
      "fat": 3.6,
      "category": { "id": "c_1", "name": "Protein", "slug": "protein" },
      "createdBy": "system",
      "createdAt": "2026-01-05T00:00:00Z",
      "aiSource": "official"
    }
    """#
    let meal = try decode(CatalogMeal.self, json)
    #expect(meal.category?.slug == "protein")
    #expect(meal.description == nil)
    #expect(meal.servingSize == nil)
    #expect(meal.aiSource == .official)
    #expect(meal.macroRanges == nil)
    #expect(meal.fat == 3.6)
  }

  @Test("Category")
  func category() throws {
    let json = #"""
    { "id": "c_1", "name": "Protein", "slug": "protein", "description": "High-protein foods", "sortOrder": 1 }
    """#
    let category = try decode(Category.self, json)
    #expect(category.name == "Protein")
    #expect(category.sortOrder == 1)
  }
}
