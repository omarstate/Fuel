import Foundation

// GET /ai/insights — the Coach's daily narrative. Cached server-side one row per
// user per UTC day (`cached: true`); `refresh=1` regenerates. Note the `facts`
// block is only returned on a freshly generated response — the cached content
// omits it — so it (and its members) are optional and the UI degrades quietly.
struct AiInsights: Decodable, Equatable, Sendable {
  let headline: String
  let insights: [Insight]
  let tips: [String]
  let day: String
  let facts: Facts?
  let cached: Bool?

  struct Insight: Decodable, Equatable, Sendable, Identifiable {
    let title: String
    let body: String
    // Stable identity for ForEach — insights carry no id, so derive one.
    var id: String { title + body }
  }

  struct Facts: Decodable, Equatable, Sendable {
    let streak: Streak?
    let targetCalories: Int?
    let targetProtein: Int?
  }

  struct Streak: Decodable, Equatable, Sendable {
    let current: Int
    let best: Int
  }

  private enum CodingKeys: String, CodingKey {
    case headline, insights, tips, day, facts, cached
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? ""
    insights = try c.decodeIfPresent([Insight].self, forKey: .insights) ?? []
    tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
    day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
    facts = try c.decodeIfPresent(Facts.self, forKey: .facts)
    cached = try c.decodeIfPresent(Bool.self, forKey: .cached)
  }

  // Test/preview convenience initializer.
  init(headline: String, insights: [Insight], tips: [String], day: String, facts: Facts?, cached: Bool?) {
    self.headline = headline
    self.insights = insights
    self.tips = tips
    self.day = day
    self.facts = facts
    self.cached = cached
  }
}
