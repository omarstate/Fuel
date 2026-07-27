import Testing
import Foundation
@testable import Fuel

// Decoding for the M3 catalog detail + paginated list shapes, and the
// omit-nil-fields encoding contract for CatalogMealInput (PATCH subset bodies).
@Suite("Catalog models")
struct CatalogModelTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  @Test("CatalogMealDetail decodes creator + stats")
  func detail() throws {
    let json = #"""
    {
      "id": "m_1",
      "name": "Koshari",
      "description": "Rice, lentils, pasta",
      "servingSize": "1 plate (450g)",
      "calories": 720,
      "protein": 22,
      "carbs": 120,
      "fat": 14,
      "category": { "id": "c_1", "name": "Egyptian", "slug": "egyptian" },
      "createdBy": "u_42",
      "createdAt": "2026-07-10T18:22:05Z",
      "aiSource": "official",
      "sourceUrl": "https://example.com/koshari",
      "creator": { "name": "Sama", "system": false },
      "stats": {
        "loggedToday": 3,
        "loggedTotal": 128,
        "uniqueLoggers": 40,
        "lastLoggedAt": "2026-07-19T08:15:00.500Z"
      }
    }
    """#
    let detail = try decode(CatalogMealDetail.self, json)
    #expect(detail.meal.name == "Koshari")
    #expect(detail.meal.category?.slug == "egyptian")
    #expect(detail.meal.sourceUrl == "https://example.com/koshari")
    #expect(detail.creator.name == "Sama")
    #expect(detail.creator.system == false)
    #expect(detail.stats.loggedTotal == 128)
    #expect(detail.stats.uniqueLoggers == 40)
    #expect(detail.stats.lastLoggedAt != nil)
    #expect(detail.id == "m_1")
  }

  @Test("CatalogMealDetail with system creator and null lastLoggedAt")
  func detailSystemNeverLogged() throws {
    let json = #"""
    {
      "id": "m_2",
      "name": "Grilled chicken",
      "calories": 165,
      "protein": 31,
      "carbs": 0,
      "fat": 3,
      "category": null,
      "createdBy": "system",
      "createdAt": "2026-01-05T00:00:00Z",
      "creator": { "name": "Fuel Team", "system": true },
      "stats": {
        "loggedToday": 0,
        "loggedTotal": 0,
        "uniqueLoggers": 0,
        "lastLoggedAt": null
      }
    }
    """#
    let detail = try decode(CatalogMealDetail.self, json)
    #expect(detail.creator.system == true)
    #expect(detail.stats.lastLoggedAt == nil)
    #expect(detail.stats.loggedTotal == 0)
    #expect(detail.meal.aiSource == nil)
  }

  @Test("Paginated meals response decodes data + count")
  func paginated() throws {
    let json = #"""
    {
      "data": [
        { "id": "m_1", "name": "A", "calories": 100, "protein": 10, "carbs": 5, "fat": 2,
          "createdAt": "2026-07-10T18:22:05Z" },
        { "id": "m_2", "name": "B", "calories": 200, "protein": 20, "carbs": 8, "fat": 4,
          "createdAt": "2026-07-11T18:22:05Z" }
      ],
      "count": 57
    }
    """#
    struct ListEnvelope: Decodable {
      let data: [CatalogMeal]
      let count: Int
    }
    let env = try decode(ListEnvelope.self, json)
    #expect(env.data.count == 2)
    #expect(env.count == 57)
    #expect(env.data.first?.name == "A")
    #expect(env.data.last?.calories == 200)
  }

  @Test("CatalogMealInput omits nil fields for a PATCH subset")
  func inputOmitsNil() throws {
    let input = CatalogMealInput(name: "New name", calories: 640)
    let data = try JSONEncoder().encode(input)
    let object = try #require(
      try JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    #expect(object["name"] as? String == "New name")
    #expect(object["calories"] as? Int == 640)
    // Every unset field must be absent, not encoded as null.
    #expect(object["description"] == nil)
    #expect(object["categoryId"] == nil)
    #expect(object["servingSize"] == nil)
    #expect(object["protein"] == nil)
    #expect(object["carbs"] == nil)
    #expect(object["fat"] == nil)
    #expect(object.keys.count == 2)
  }

  @Test("CatalogMealInput encodes a full create body")
  func inputFullBody() throws {
    let input = CatalogMealInput(
      name: "Koshari", description: "Rice", categoryId: "c_1",
      servingSize: "1 plate", calories: 720, protein: 22, carbs: 120, fat: 14
    )
    let data = try JSONEncoder().encode(input)
    let object = try #require(
      try JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    #expect(object.keys.count == 8)
    #expect(object["categoryId"] as? String == "c_1")
    #expect(object["fat"] as? Int == 14)
  }

  @Test("canEdit: admin, creator, and neither")
  func canEdit() {
    let meal = CatalogMeal(
      id: "m", name: "x", description: nil, servingSize: nil,
      calories: 1, protein: 0, carbs: 0, fat: 0,
      category: nil, createdBy: "u_1", createdAt: Date(),
      aiSource: nil, sourceUrl: nil, macroRanges: nil
    )
    #expect(meal.canEdit(Me(id: "u_1", email: "a@b.c", isAdmin: false)) == true)
    #expect(meal.canEdit(Me(id: "u_2", email: "a@b.c", isAdmin: true)) == true)
    #expect(meal.canEdit(Me(id: "u_2", email: "a@b.c", isAdmin: false)) == false)
    #expect(meal.canEdit(nil) == false)
  }
}
