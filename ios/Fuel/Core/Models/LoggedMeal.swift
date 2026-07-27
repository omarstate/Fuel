import Foundation

// A row in public.meals — the user's personal meal log (RLS own-row). Written
// directly with supabase-js on the web (frontend/src/app-editorial/use-meals.ts)
// and with supabase-swift here; the same live table backs both clients.
//
// Coding is fully self-contained (snake_case keys, `logged_at` as an explicit
// ISO8601-with-fractional-seconds UTC string, lenient integer macros) so the
// model round-trips identically no matter which JSONEncoder/Decoder drives it —
// the PostgREST client's, or a plain one in tests.
struct LoggedMeal: Codable, Equatable, Sendable, Identifiable {
  var id: UUID
  var userId: UUID
  var name: String
  var mealType: MealType
  var servingSize: String?
  var calories: Int
  var protein: Int
  var carbs: Int
  var fat: Int
  var loggedAt: Date
  var catalogMealId: UUID?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name
    case mealType = "meal_type"
    case servingSize = "serving_size"
    case calories
    case protein
    case carbs
    case fat
    case loggedAt = "logged_at"
    case catalogMealId = "catalog_meal_id"
  }

  init(
    id: UUID = UUID(),
    userId: UUID,
    name: String,
    mealType: MealType,
    servingSize: String? = nil,
    calories: Int,
    protein: Int,
    carbs: Int,
    fat: Int,
    loggedAt: Date = Date(),
    catalogMealId: UUID? = nil
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.mealType = mealType
    self.servingSize = servingSize
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.loggedAt = loggedAt
    self.catalogMealId = catalogMealId
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    userId = try c.decode(UUID.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    mealType = try c.decode(MealType.self, forKey: .mealType)
    servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize)
    calories = try Self.lenially(c, .calories)
    protein = try Self.lenially(c, .protein)
    carbs = try Self.lenially(c, .carbs)
    fat = try Self.lenially(c, .fat)
    catalogMealId = try c.decodeIfPresent(UUID.self, forKey: .catalogMealId)

    let raw = try c.decode(String.self, forKey: .loggedAt)
    guard let date = Self.parseTimestamp(raw) else {
      throw DecodingError.dataCorruptedError(
        forKey: .loggedAt, in: c,
        debugDescription: "Unrecognized logged_at timestamp: \(raw)"
      )
    }
    loggedAt = date
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encode(name, forKey: .name)
    try c.encode(mealType, forKey: .mealType)
    try c.encode(servingSize, forKey: .servingSize) // encodes null for nil
    try c.encode(calories, forKey: .calories)
    try c.encode(protein, forKey: .protein)
    try c.encode(carbs, forKey: .carbs)
    try c.encode(fat, forKey: .fat)
    try c.encode(ISO8601DateFormatter.fuelWithFractional.string(from: loggedAt), forKey: .loggedAt)
    try c.encode(catalogMealId, forKey: .catalogMealId)
  }

  // AI-sourced rows may arrive as doubles where the DB stores ints — round.
  private static func lenially(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Int {
    if let i = try? c.decode(Int.self, forKey: key) { return i }
    let d = try c.decode(Double.self, forKey: key)
    return Int(d.rounded())
  }

  private static func parseTimestamp(_ raw: String) -> Date? {
    ISO8601DateFormatter.fuelWithFractional.date(from: raw)
      ?? ISO8601DateFormatter.fuelPlain.date(from: raw)
  }
}

extension LoggedMeal {
  /// Convenience macro totals reducer used across Today/History.
  struct Totals: Equatable, Sendable {
    var calories = 0
    var protein = 0
    var carbs = 0
    var fat = 0
  }
}

extension Sequence where Element == LoggedMeal {
  var totals: LoggedMeal.Totals {
    reduce(into: LoggedMeal.Totals()) { acc, m in
      acc.calories += m.calories
      acc.protein += m.protein
      acc.carbs += m.carbs
      acc.fat += m.fat
    }
  }
}
