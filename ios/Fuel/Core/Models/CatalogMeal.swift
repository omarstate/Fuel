import Foundation

// Shared meal catalog. Used from M3 onward; defined now so decoding is tested.
struct Category: Codable, Equatable, Sendable, Identifiable {
  let id: String
  let name: String
  let slug: String
  let description: String?
  let sortOrder: Int
}

struct CatalogMeal: Codable, Equatable, Hashable, Sendable, Identifiable {
  let id: String
  let name: String
  let description: String?
  let servingSize: String?
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  let category: CategoryRef?
  let createdBy: String?
  let createdAt: Date
  let aiSource: AISource?
  let sourceUrl: String?
  let macroRanges: MacroRanges?

  // The lightweight category shape joined onto a catalog meal.
  struct CategoryRef: Codable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
  }

  enum AISource: String, Codable, Equatable, Hashable, Sendable {
    case official
    case estimate
  }

  // jsonb min/max ranges, shown as ranges in the UI. Each is a [min, max] pair.
  struct MacroRanges: Codable, Equatable, Hashable, Sendable {
    let calories: MacroRange
    let protein: MacroRange
    let carbs: MacroRange
    let fat: MacroRange
  }

  // Decoded from a two-element JSON array [min, max].
  struct MacroRange: Codable, Equatable, Hashable, Sendable {
    let min: Double
    let max: Double

    init(min: Double, max: Double) {
      self.min = min
      self.max = max
    }

    init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      let first = try container.decode(Double.self)
      let second = try container.decode(Double.self)
      self.min = first
      self.max = second
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.unkeyedContainer()
      try container.encode(min)
      try container.encode(max)
    }
  }
}
