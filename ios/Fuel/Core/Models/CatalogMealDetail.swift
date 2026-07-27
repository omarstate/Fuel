import Foundation

// GET /api/meals/:id — a CatalogMeal plus the extra `creator` and `stats`
// fields the detail view shows. Decoded by pulling the CatalogMeal fields off
// the same top-level container (shared keys) and the two extra objects beside
// them, so the base model stays the single source of truth for a meal's shape.
struct CatalogMealDetail: Decodable, Equatable, Sendable, Identifiable {
  let meal: CatalogMeal
  let creator: Creator
  let stats: Stats

  var id: String { meal.id }

  // Who added the meal — the API resolves a display name and a `system` flag
  // (true for the seeded "Fuel Team" catalog).
  struct Creator: Decodable, Equatable, Sendable {
    let name: String
    let system: Bool
  }

  // Aggregate log stats across all users, for the "Fun stats" section.
  struct Stats: Decodable, Equatable, Sendable {
    let loggedToday: Int
    let loggedTotal: Int
    let uniqueLoggers: Int
    let lastLoggedAt: Date?
  }

  private enum CodingKeys: String, CodingKey {
    case creator
    case stats
  }

  init(from decoder: Decoder) throws {
    self.meal = try CatalogMeal(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.creator = try c.decode(Creator.self, forKey: .creator)
    self.stats = try c.decode(Stats.self, forKey: .stats)
  }
}

// POST /api/meals and PATCH /api/meals/:id body. Every field is optional and
// encoded only when present, so a PATCH with a nil field leaves the stored
// value untouched (mirrors the web app's `undefined`-omission semantics).
struct CatalogMealInput: Encodable, Equatable, Sendable {
  var name: String?
  var description: String?
  var categoryId: String?
  var servingSize: String?
  var calories: Int?
  var protein: Int?
  var carbs: Int?
  var fat: Int?

  private enum CodingKeys: String, CodingKey {
    case name, description, categoryId, servingSize, calories, protein, carbs, fat
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(name, forKey: .name)
    try c.encodeIfPresent(description, forKey: .description)
    try c.encodeIfPresent(categoryId, forKey: .categoryId)
    try c.encodeIfPresent(servingSize, forKey: .servingSize)
    try c.encodeIfPresent(calories, forKey: .calories)
    try c.encodeIfPresent(protein, forKey: .protein)
    try c.encodeIfPresent(carbs, forKey: .carbs)
    try c.encodeIfPresent(fat, forKey: .fat)
  }
}

extension CatalogMeal {
  /// Mirrors the web `canEditMeal` rule: admins can edit anything, otherwise
  /// only the meal's own creator can.
  func canEdit(_ me: Me?) -> Bool {
    guard let me else { return false }
    if me.isAdmin { return true }
    guard let createdBy else { return false }
    return createdBy == me.id
  }
}
