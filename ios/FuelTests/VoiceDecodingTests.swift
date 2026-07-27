import Testing
import Foundation
@testable import Fuel

// Pins the POST /ai/meals/voice-log contract the app decodes: items are
// discriminated by `kind` ("catalog" carries a full CatalogMeal + factor,
// "estimate" carries its own macros), `mealType` is null when the user didn't say
// which meal, `ok: false` is a soft failure with zeroed macros and a manual-entry
// note, and the commit response echoes each input name so created catalog ids can
// be mapped back to review rows. Fixtures are shaped exactly like the real
// responses, including int-vs-double numeric sloppiness from the model.
@Suite("Voice log decoding")
struct VoiceDecodingTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  @Test("Catalog match carries the meal, spoken phrase and factor")
  func catalogItem() throws {
    let json = #"""
    {
      "mealType": "breakfast",
      "items": [
        {
          "kind": "catalog",
          "spoken": "تلات بيضات مسلوقين",
          "quantity": 3,
          "unit": "بيضة",
          "factor": 3,
          "meal": {
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Boiled Eggs",
            "description": null,
            "servingSize": "1 egg (50g)",
            "calories": 78,
            "protein": 6.3,
            "carbs": 0.6,
            "fat": 5.3,
            "category": { "id": "c_1", "name": "Breakfast", "slug": "breakfast" },
            "createdBy": "system",
            "createdAt": "2026-01-05T00:00:00Z",
            "aiSource": "official",
            "sourceUrl": null,
            "macroRanges": null
          }
        }
      ]
    }
    """#
    let response = try decode(VoiceLogResponse.self, json)
    #expect(response.mealType == .breakfast)
    #expect(response.items.count == 1)

    guard case .catalog(let item) = response.items[0] else {
      Issue.record("expected a catalog item")
      return
    }
    #expect(item.spoken == "تلات بيضات مسلوقين")
    #expect(item.quantity == 3)
    #expect(item.factor == 3)
    #expect(item.meal.name == "Boiled Eggs")
    #expect(item.meal.servingSize == "1 egg (50g)")
    #expect(item.meal.calories == 78)
  }

  @Test("Estimate with ranges and a source decodes fully")
  func estimateWithRanges() throws {
    let json = #"""
    {
      "mealType": null,
      "items": [
        {
          "kind": "estimate",
          "ok": true,
          "spoken": "200ml skimmed milk",
          "quantity": 200,
          "unit": "ml",
          "name": "Skimmed Milk",
          "servingSize": "200 ml",
          "calories": 70,
          "protein": 7,
          "carbs": 10,
          "fat": 0.4,
          "ranges": {
            "calories": [66, 76],
            "protein": [6, 8],
            "carbs": [9, 11],
            "fat": [0, 1]
          },
          "sourceUrl": "https://www.juhayna.com/products/skimmed-milk",
          "confidence": "high",
          "note": "Egyptian Juhayna skimmed milk, per 200 ml."
        }
      ]
    }
    """#
    let response = try decode(VoiceLogResponse.self, json)
    #expect(response.mealType == nil)   // user never said a meal — never guessed

    guard case .estimate(let item) = response.items[0] else {
      Issue.record("expected an estimate item")
      return
    }
    #expect(item.ok)
    #expect(item.name == "Skimmed Milk")
    #expect(item.servingSize == "200 ml")
    #expect(item.calories == 70)
    #expect(item.fat == 0.4)           // doubles survive
    #expect(item.confidence == .high)
    #expect(item.ranges?.calories.min == 66)
    #expect(item.ranges?.calories.max == 76)
    #expect(item.ranges?.fat.max == 1)
    #expect(item.sourceUrl?.contains("juhayna") == true)
  }

  @Test("Soft failure keeps the spoken words and zeroed macros")
  func softFailure() throws {
    let json = #"""
    {
      "mealType": "snack",
      "items": [
        {
          "kind": "estimate",
          "ok": false,
          "spoken": "حاجة غريبة",
          "quantity": null,
          "unit": null,
          "name": "حاجة غريبة",
          "servingSize": "",
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fat": 0,
          "ranges": null,
          "sourceUrl": null,
          "confidence": null,
          "note": "مقدرناش نحسب العنصر ده لوحدنا — دخّل السعرات والماكروز بنفسك."
        }
      ]
    }
    """#
    let response = try decode(VoiceLogResponse.self, json)
    #expect(response.mealType == .snack)

    guard case .estimate(let item) = response.items[0] else {
      Issue.record("expected an estimate item")
      return
    }
    #expect(item.ok == false)
    #expect(item.quantity == nil)
    #expect(item.unit == nil)
    #expect(item.confidence == nil)
    #expect(item.ranges == nil)
    #expect(item.calories == 0)
    #expect(item.note.isEmpty == false)
  }

  @Test("Mixed response keeps items in spoken order")
  func mixedOrder() throws {
    let json = #"""
    {
      "mealType": "lunch",
      "items": [
        {
          "kind": "catalog", "spoken": "koshari", "quantity": 1, "unit": "plate", "factor": 1,
          "meal": {
            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "name": "Koshari", "description": null,
            "servingSize": "1 plate (450g)", "calories": 720, "protein": 22, "carbs": 120, "fat": 14,
            "category": null, "createdBy": "system", "createdAt": "2026-01-05T00:00:00Z"
          }
        },
        {
          "kind": "estimate", "ok": true, "spoken": "كوباية عصير مانجو", "quantity": 1, "unit": "كوباية",
          "name": "Mango Juice", "servingSize": "1 cup (240ml)",
          "calories": 130, "protein": 1, "carbs": 32, "fat": 0,
          "ranges": null, "sourceUrl": null, "confidence": "medium", "note": ""
        }
      ]
    }
    """#
    let response = try decode(VoiceLogResponse.self, json)
    #expect(response.items.count == 2)
    #expect(response.items[0].spoken == "koshari")
    #expect(response.items[1].spoken == "كوباية عصير مانجو")

    // Optional AI-provenance columns may be absent entirely (pre-0008 rows).
    guard case .catalog(let first) = response.items[0] else {
      Issue.record("expected a catalog item first")
      return
    }
    #expect(first.meal.aiSource == nil)
    #expect(first.meal.category == nil)
  }

  @Test("Missing factor falls back to 1")
  func missingFactor() throws {
    let json = #"""
    {
      "kind": "catalog", "spoken": "toast", "quantity": null, "unit": null,
      "meal": {
        "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "name": "Toast", "description": null,
        "servingSize": "1 slice", "calories": 80, "protein": 3, "carbs": 14, "fat": 1,
        "category": null, "createdBy": null, "createdAt": "2026-01-05T00:00:00Z"
      }
    }
    """#
    let item = try decode(VoiceLogItem.self, json)
    guard case .catalog(let match) = item else {
      Issue.record("expected a catalog item")
      return
    }
    #expect(match.factor == 1)
  }

  @Test("Commit response maps echoed names to created catalog ids")
  func commitResponse() throws {
    let json = #"""
    {
      "meals": [
        {
          "name": "Skimmed Milk",
          "meal": {
            "id": "99999999-8888-7777-6666-555555555555",
            "name": "Skimmed Milk", "description": null, "servingSize": "200 ml",
            "calories": 70, "protein": 7, "carbs": 10, "fat": 0,
            "category": { "id": "c_9", "name": "AI Discovered", "slug": "ai-discovered" },
            "createdBy": "u_1", "createdAt": "2026-07-27T09:15:00.123Z",
            "aiSource": "estimate", "sourceUrl": "https://example.com/milk",
            "macroRanges": { "calories": [66, 76], "protein": [6, 8], "carbs": [9, 11], "fat": [0, 1] }
          }
        }
      ],
      "aliasesUpdated": 2
    }
    """#
    let response = try decode(VoiceCommitResponse.self, json)
    #expect(response.aliasesUpdated == 2)
    #expect(response.meals.count == 1)
    #expect(response.catalogId(for: "Skimmed Milk") == "99999999-8888-7777-6666-555555555555")
    #expect(response.catalogId(for: "skimmed milk") == "99999999-8888-7777-6666-555555555555")
    #expect(response.catalogId(for: "Boiled Eggs") == nil)
    #expect(response.meals[0].meal.aiSource == .estimate)
    #expect(response.meals[0].meal.macroRanges?.protein.max == 8)
  }

  @Test("Empty commit response decodes to zeros")
  func emptyCommitResponse() throws {
    let response = try decode(VoiceCommitResponse.self, #"{ "meals": [], "aliasesUpdated": 0 }"#)
    #expect(response.meals.isEmpty)
    #expect(response.aliasesUpdated == 0)
  }
}
