import Foundation

// POST /ai/meals/suggest — which library meals best fill what's LEFT of today's
// macros. Deterministic + fast server-side (no Gemini call); works even when AI
// is unconfigured.
struct MealSuggestion: Decodable, Equatable, Sendable, Identifiable {
  let meal: CatalogMeal
  let reason: String

  var id: String { meal.id }
}

struct SuggestResponse: Decodable, Equatable, Sendable {
  let suggestions: [MealSuggestion]
  let targetReached: Bool
  let aiUsed: Bool

  private enum CodingKeys: String, CodingKey {
    case suggestions, targetReached, aiUsed
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    suggestions = try c.decodeIfPresent([MealSuggestion].self, forKey: .suggestions) ?? []
    targetReached = try c.decodeIfPresent(Bool.self, forKey: .targetReached) ?? false
    aiUsed = try c.decodeIfPresent(Bool.self, forKey: .aiUsed) ?? false
  }

  init(suggestions: [MealSuggestion], targetReached: Bool, aiUsed: Bool) {
    self.suggestions = suggestions
    self.targetReached = targetReached
    self.aiUsed = aiUsed
  }
}

// POST body for /ai/meals/suggest — the client sends `remaining` (already
// clamped) so the app's local-time "today" isn't second-guessed server-side.
struct SuggestBody: Encodable, Sendable {
  let remaining: RemainingMacros
  let lang: String
}
