import Testing
import Foundation
@testable import Fuel

// Decoding fixtures shaped like the real AI endpoint responses: insights (fresh
// with facts, and cached without), suggest (populated and target-reached-empty),
// lookup items, and the lenient EstimatedMeal numerics + null source/confidence.
@Suite("AI model decoding")
struct AiDecodingTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  @Test("AiInsights fresh response with facts")
  func insightsFresh() throws {
    let json = #"""
    {
      "headline": "Strong week — keep the streak alive!",
      "insights": [
        { "title": "On target", "body": "You're averaging 2,100 kcal over the last week." },
        { "title": "Protein", "body": "Protein has been solid — 130g/day on average." }
      ],
      "tips": ["Add a protein source to breakfast", "Front-load carbs earlier in the day"],
      "day": "2026-07-19",
      "facts": { "streak": { "current": 5, "best": 12 }, "targetCalories": 2200, "targetProtein": 165 },
      "cached": false
    }
    """#
    let insights = try decode(AiInsights.self, json)
    #expect(insights.headline.hasPrefix("Strong week"))
    #expect(insights.insights.count == 2)
    #expect(insights.insights.first?.title == "On target")
    #expect(insights.tips.count == 2)
    #expect(insights.day == "2026-07-19")
    #expect(insights.facts?.streak?.current == 5)
    #expect(insights.facts?.streak?.best == 12)
    #expect(insights.facts?.targetCalories == 2200)
    #expect(insights.cached == false)
  }

  @Test("AiInsights cached response omits facts")
  func insightsCached() throws {
    let json = #"""
    {
      "headline": "Nice and steady today.",
      "insights": [{ "title": "Balanced", "body": "Macros are on track." }],
      "tips": ["Drink water"],
      "day": "2026-07-19",
      "cached": true
    }
    """#
    let insights = try decode(AiInsights.self, json)
    #expect(insights.facts == nil)          // cached content carries no facts
    #expect(insights.cached == true)
    #expect(insights.insights.count == 1)
  }

  @Test("SuggestResponse with suggestions")
  func suggestPopulated() throws {
    let json = #"""
    {
      "suggestions": [
        {
          "meal": {
            "id": "m_1", "name": "Grilled chicken", "calories": 165, "protein": 31, "carbs": 0, "fat": 3.6,
            "category": { "id": "c_1", "name": "Protein", "slug": "protein" },
            "createdBy": "system", "createdAt": "2026-01-05T00:00:00Z", "aiSource": "official"
          },
          "reason": "High in protein, fits your remaining macros."
        }
      ],
      "targetReached": false,
      "aiUsed": false
    }
    """#
    let response = try decode(SuggestResponse.self, json)
    #expect(response.suggestions.count == 1)
    #expect(response.suggestions.first?.meal.name == "Grilled chicken")
    #expect(response.suggestions.first?.reason.contains("protein") == true)
    #expect(response.targetReached == false)
    #expect(response.aiUsed == false)
  }

  @Test("SuggestResponse target reached with empty suggestions")
  func suggestTargetReached() throws {
    let json = #"{ "suggestions": [], "targetReached": true, "aiUsed": false }"#
    let response = try decode(SuggestResponse.self, json)
    #expect(response.suggestions.isEmpty)
    #expect(response.targetReached == true)
  }

  @Test("AiLookupResponse items with created flag and estimate ranges")
  func lookupItems() throws {
    let json = #"""
    {
      "items": [
        {
          "meal": {
            "id": "m_a", "name": "Koshari", "servingSize": "1 plate", "calories": 720, "protein": 22, "carbs": 120, "fat": 14,
            "category": null, "createdBy": null, "createdAt": "2026-07-10T18:22:05Z",
            "aiSource": "estimate", "sourceUrl": "https://www.example.com/koshari",
            "macroRanges": { "calories": [640, 800], "protein": [18, 26], "carbs": [110, 130], "fat": [10, 18] }
          },
          "created": true
        },
        {
          "meal": {
            "id": "m_b", "name": "Grilled chicken", "calories": 165, "protein": 31, "carbs": 0, "fat": 4,
            "category": { "id": "c", "name": "Protein", "slug": "protein" },
            "createdBy": "system", "createdAt": "2026-01-01T00:00:00Z", "aiSource": "official"
          },
          "created": false
        }
      ],
      "usedAi": true
    }
    """#
    let response = try decode(AiLookupResponse.self, json)
    #expect(response.items.count == 2)
    #expect(response.items[0].created == true)
    #expect(response.items[0].meal.aiSource == .estimate)
    #expect(response.items[0].meal.macroRanges?.calories.max == 800)
    #expect(response.items[1].created == false)
    #expect(response.usedAi == true)
  }

  @Test("EstimatedMeal decodes lenient numerics and null source/confidence")
  func estimatedLenient() throws {
    let json = #"""
    [
      {
        "input": "koshari", "ok": true, "name": "Koshari", "servingSize": "1 plate (450g)",
        "calories": 718.6, "protein": 21.4, "carbs": 119.9, "fat": 13.5,
        "source": "egypt", "confidence": "high", "note": "Typical street portion."
      },
      {
        "input": "some obscure dish", "ok": false, "name": "", "servingSize": "",
        "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
        "source": null, "confidence": null, "note": "Couldn't find reliable data."
      }
    ]
    """#
    let meals = try decode([EstimatedMeal].self, json)
    #expect(meals.count == 2)
    #expect(meals[0].ok == true)
    #expect(meals[0].calories == 718.6)   // double preserved; rounded at the edges
    #expect(meals[0].source == .egypt)
    #expect(meals[0].confidence == .high)
    #expect(meals[1].ok == false)
    #expect(meals[1].source == nil)
    #expect(meals[1].confidence == nil)
    #expect(meals[1].name.isEmpty)
  }
}
