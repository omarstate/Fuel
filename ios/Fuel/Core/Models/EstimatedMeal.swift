import Foundation

// POST /meals/estimate — one grounded Gemini estimate per free-text item, in
// input order, Egypt-first. Slow (a call per item). `ok == false` is a SOFT
// failure (fill in by hand), never an error. Macros may arrive as doubles where
// the DB stores ints, so they decode leniently as Double and round at the edges.
struct EstimatedMeal: Decodable, Equatable, Sendable {
  let input: String
  let ok: Bool
  let name: String
  let servingSize: String
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  let source: Source?
  let confidence: Confidence?
  let note: String

  enum Source: String, Decodable, Equatable, Sendable {
    case egypt, regional, global

    var label: String {
      switch self {
      case .egypt: return "🇪🇬 Egypt"
      case .regional: return String(localized: "Regional")
      case .global: return String(localized: "Global")
      }
    }
  }

  enum Confidence: String, Decodable, Equatable, Sendable {
    case high, medium, low

    var label: String {
      switch self {
      case .high: return String(localized: "High")
      case .medium: return String(localized: "Medium")
      case .low: return String(localized: "Low")
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case input, ok, name, servingSize, calories, protein, carbs, fat, source, confidence, note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    input = try c.decodeIfPresent(String.self, forKey: .input) ?? ""
    ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize) ?? ""
    calories = Self.lenientDouble(c, .calories)
    protein = Self.lenientDouble(c, .protein)
    carbs = Self.lenientDouble(c, .carbs)
    fat = Self.lenientDouble(c, .fat)
    source = try? c.decodeIfPresent(Source.self, forKey: .source)
    confidence = try? c.decodeIfPresent(Confidence.self, forKey: .confidence)
    note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
  }

  init(
    input: String, ok: Bool, name: String, servingSize: String,
    calories: Double, protein: Double, carbs: Double, fat: Double,
    source: Source?, confidence: Confidence?, note: String
  ) {
    self.input = input
    self.ok = ok
    self.name = name
    self.servingSize = servingSize
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.source = source
    self.confidence = confidence
    self.note = note
  }

  // Accepts int or double; missing/garbage → 0.
  private static func lenientDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    return 0
  }
}

// POST /meals/estimate body. `place` is omitted when nil so the server applies
// its Egypt-first default; `items` is the already-split comma list.
struct EstimateBody: Encodable, Sendable {
  let place: String?
  let items: [String]
  let lang: String

  private enum CodingKeys: String, CodingKey { case place, items, lang }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(place, forKey: .place)
    try c.encode(items, forKey: .items)
    try c.encode(lang, forKey: .lang)
  }
}

// POST /meals/ai-catalog — best-effort save of reviewed AI rows into the shared
// catalog (server dedupes by name). Failures never block logging the day.
struct AiCatalogMealInput: Encodable, Equatable, Sendable {
  let name: String
  let description: String?
  let servingSize: String?
  let calories: Int
  let protein: Int
  let carbs: Int
  let fat: Int

  private enum CodingKeys: String, CodingKey {
    case name, description, servingSize, calories, protein, carbs, fat
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encodeIfPresent(description, forKey: .description)
    try c.encodeIfPresent(servingSize, forKey: .servingSize)
    try c.encode(calories, forKey: .calories)
    try c.encode(protein, forKey: .protein)
    try c.encode(carbs, forKey: .carbs)
    try c.encode(fat, forKey: .fat)
  }
}

struct AiCatalogBody: Encodable, Sendable {
  let meals: [AiCatalogMealInput]
}
