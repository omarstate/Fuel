import Foundation

// POST /ai/meals/lookup — a grounded search that returns catalog matches first
// (never duplicates) then AI estimates, persisting new catalog meals as it goes.
// `created: true` means a new catalog row was written (the Library re-fetches on
// its own staleness). Slow — 10–30s — but within the client's 75s timeout.
struct AiLookupItem: Decodable, Equatable, Sendable, Identifiable {
  let meal: CatalogMeal
  let created: Bool

  var id: String { meal.id }
}

struct AiLookupResponse: Decodable, Equatable, Sendable {
  let items: [AiLookupItem]
  let usedAi: Bool

  private enum CodingKeys: String, CodingKey {
    case items, usedAi
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    items = try c.decodeIfPresent([AiLookupItem].self, forKey: .items) ?? []
    usedAi = try c.decodeIfPresent(Bool.self, forKey: .usedAi) ?? false
  }
}

struct LookupBody: Encodable, Sendable {
  let query: String
  let lang: String
}
