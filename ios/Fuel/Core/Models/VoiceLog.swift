import Foundation

// POST /ai/meals/voice-log — the spoken transcript in, loggable items out. One
// Gemini call parses the utterance (Egyptian Arabic or English) into items +
// quantities + the target section AND matches each item against the catalog;
// whatever it can't match comes back as a grounded, Egypt-first estimate for the
// amount the user actually spoke.
//
// `kind` is the discriminator: "catalog" carries a full CatalogMeal plus the
// serving `factor` the model worked out, "estimate" carries macros of its own.
// An estimate with `ok: false` is a SOFT failure (fill it in by hand), never an
// error. Numerics decode leniently (int or double) like EstimatedMeal, since the
// values originate from a language model.

struct VoiceLogBody: Encodable, Sendable {
  let transcript: String
  let lang: String
}

enum VoiceConfidence: String, Decodable, Equatable, Sendable {
  case high, medium, low

  var label: String {
    switch self {
    case .high: return String(localized: "High")
    case .medium: return String(localized: "Medium")
    case .low: return String(localized: "Low")
    }
  }
}

// An item the model matched to a meal already in the catalog. `factor` is the
// spoken amount ÷ that meal's serving size (clamped server-side, never nil).
struct VoiceCatalogItem: Decodable, Equatable, Sendable {
  let spoken: String
  let quantity: Double?
  let unit: String?
  let factor: Double
  let meal: CatalogMeal

  private enum CodingKeys: String, CodingKey {
    case spoken, quantity, unit, factor, meal
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    spoken = try c.decodeIfPresent(String.self, forKey: .spoken) ?? ""
    quantity = try? c.decodeIfPresent(Double.self, forKey: .quantity)
    unit = try c.decodeIfPresent(String.self, forKey: .unit)
    factor = (try? c.decodeIfPresent(Double.self, forKey: .factor)) ?? 1
    meal = try c.decode(CatalogMeal.self, forKey: .meal)
  }

  init(spoken: String, quantity: Double?, unit: String?, factor: Double, meal: CatalogMeal) {
    self.spoken = spoken
    self.quantity = quantity
    self.unit = unit
    self.factor = factor
    self.meal = meal
  }
}

// An item the model estimated instead of matching. Macros already cover the
// spoken amount, so `servingSize` reads like "3 eggs (~150g)".
struct VoiceEstimateItem: Decodable, Equatable, Sendable {
  let ok: Bool
  let spoken: String
  let quantity: Double?
  let unit: String?
  let name: String
  let servingSize: String
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  let ranges: CatalogMeal.MacroRanges?
  let sourceUrl: String?
  let confidence: VoiceConfidence?
  let note: String

  private enum CodingKeys: String, CodingKey {
    case ok, spoken, quantity, unit, name, servingSize
    case calories, protein, carbs, fat, ranges, sourceUrl, confidence, note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    spoken = try c.decodeIfPresent(String.self, forKey: .spoken) ?? ""
    quantity = try? c.decodeIfPresent(Double.self, forKey: .quantity)
    unit = try c.decodeIfPresent(String.self, forKey: .unit)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize) ?? ""
    calories = Self.lenientDouble(c, .calories)
    protein = Self.lenientDouble(c, .protein)
    carbs = Self.lenientDouble(c, .carbs)
    fat = Self.lenientDouble(c, .fat)
    ranges = try? c.decodeIfPresent(CatalogMeal.MacroRanges.self, forKey: .ranges)
    sourceUrl = try c.decodeIfPresent(String.self, forKey: .sourceUrl)
    confidence = try? c.decodeIfPresent(VoiceConfidence.self, forKey: .confidence)
    note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
  }

  init(
    ok: Bool, spoken: String, quantity: Double?, unit: String?, name: String, servingSize: String,
    calories: Double, protein: Double, carbs: Double, fat: Double,
    ranges: CatalogMeal.MacroRanges?, sourceUrl: String?, confidence: VoiceConfidence?, note: String
  ) {
    self.ok = ok
    self.spoken = spoken
    self.quantity = quantity
    self.unit = unit
    self.name = name
    self.servingSize = servingSize
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.ranges = ranges
    self.sourceUrl = sourceUrl
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

// Discriminated by `kind`. Anything that isn't "catalog" decodes as an estimate —
// the estimate shape is fully lenient, so an unknown future kind degrades into a
// hand-editable row instead of failing the whole response.
enum VoiceLogItem: Decodable, Equatable, Sendable {
  case catalog(VoiceCatalogItem)
  case estimate(VoiceEstimateItem)

  private enum CodingKeys: String, CodingKey { case kind }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
    if kind == "catalog" {
      self = .catalog(try VoiceCatalogItem(from: decoder))
    } else {
      self = .estimate(try VoiceEstimateItem(from: decoder))
    }
  }

  /// The words the user actually said for this item, whichever kind it is.
  var spoken: String {
    switch self {
    case .catalog(let item): return item.spoken
    case .estimate(let item): return item.spoken
    }
  }
}

struct VoiceLogResponse: Decodable, Equatable, Sendable {
  /// The section the user named out loud, or nil when they didn't say.
  let mealType: MealType?
  let items: [VoiceLogItem]

  private enum CodingKeys: String, CodingKey { case mealType, items }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    mealType = try? c.decodeIfPresent(MealType.self, forKey: .mealType)
    items = try c.decodeIfPresent([VoiceLogItem].self, forKey: .items) ?? []
  }

  init(mealType: MealType?, items: [VoiceLogItem]) {
    self.mealType = mealType
    self.items = items
  }
}

// MARK: - Commit (catalog side only)

// POST /ai/meals/voice-log/commit — saves confirmed estimates into the shared
// catalog and teaches matched meals the phrase the user spoke. Best-effort by
// design: the log rows are written straight to Supabase either way.
struct VoiceCommitMealInput: Encodable, Equatable, Sendable {
  let name: String
  let servingSize: String
  let calories: Int
  let protein: Int
  let carbs: Int
  let fat: Int
  let sourceUrl: String?
  let ranges: CatalogMeal.MacroRanges?
  let aliases: [String]
}

struct VoiceAliasUpdate: Encodable, Equatable, Sendable {
  let catalogMealId: String
  let aliases: [String]
}

struct VoiceCommitBody: Encodable, Sendable {
  let newMeals: [VoiceCommitMealInput]
  let aliasUpdates: [VoiceAliasUpdate]
}

struct VoiceCommitResponse: Decodable, Equatable, Sendable {
  let meals: [Created]
  let aliasesUpdated: Int

  // `name` echoes the request so the app can map a created meal back to the
  // review row that produced it and link its log entry to the new catalog id.
  struct Created: Decodable, Equatable, Sendable {
    let name: String
    let meal: CatalogMeal
  }

  private enum CodingKeys: String, CodingKey { case meals, aliasesUpdated }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    meals = try c.decodeIfPresent([Created].self, forKey: .meals) ?? []
    aliasesUpdated = (try? c.decodeIfPresent(Int.self, forKey: .aliasesUpdated)) ?? 0
  }

  init(meals: [Created], aliasesUpdated: Int) {
    self.meals = meals
    self.aliasesUpdated = aliasesUpdated
  }

  /// The catalog id created for `name`, matched case-insensitively.
  func catalogId(for name: String) -> String? {
    let key = name.lowercased()
    return meals.first { $0.name.lowercased() == key }?.meal.id
  }
}
