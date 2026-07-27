import Foundation

// GET /meals/barcode/:code -> BarcodeProduct. Open Food Facts proxy, normalized
// to the same per-basis shape the photo extraction returns so the review/scale/
// log step is shared. `found == false` means the code isn't in the database and
// `found == true, ok == false` means a known product with no usable macros —
// both are SOFT states (offer manual entry / label photo), never errors.
//
// Macros decode leniently (int OR double) and default to 0, matching the AI
// endpoints; `servingGrams` is a lenient optional.
struct BarcodeProduct: Decodable, Equatable, Sendable, LabelSource {
  let found: Bool
  let ok: Bool
  let barcode: String
  let name: String?
  let brand: String?
  let basis: LabelBasis
  let servingSize: String
  let servingGrams: Double?
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  let confidence: LabelConfidence?
  let note: String

  private enum CodingKeys: String, CodingKey {
    case found, ok, barcode, name, brand, basis, servingSize, servingGrams
    case calories, protein, carbs, fat, confidence, note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    found = try c.decodeIfPresent(Bool.self, forKey: .found) ?? false
    ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    barcode = try c.decodeIfPresent(String.self, forKey: .barcode) ?? ""
    name = try c.decodeIfPresent(String.self, forKey: .name)
    brand = try c.decodeIfPresent(String.self, forKey: .brand)
    basis = (try? c.decodeIfPresent(LabelBasis.self, forKey: .basis)) ?? .per100g
    servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize) ?? ""
    servingGrams = LenientNumber.optionalDouble(c, .servingGrams)
    calories = LenientNumber.double(c, .calories)
    protein = LenientNumber.double(c, .protein)
    carbs = LenientNumber.double(c, .carbs)
    fat = LenientNumber.double(c, .fat)
    confidence = try? c.decodeIfPresent(LabelConfidence.self, forKey: .confidence)
    note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
  }

  // Direct init for previews/tests.
  init(
    found: Bool, ok: Bool, barcode: String, name: String?, brand: String?,
    basis: LabelBasis, servingSize: String, servingGrams: Double?,
    calories: Double, protein: Double, carbs: Double, fat: Double,
    confidence: LabelConfidence?, note: String
  ) {
    self.found = found
    self.ok = ok
    self.barcode = barcode
    self.name = name
    self.brand = brand
    self.basis = basis
    self.servingSize = servingSize
    self.servingGrams = servingGrams
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.confidence = confidence
    self.note = note
  }
}

// Shared lenient numeric decoding for the label DTOs. The proxied Open Food
// Facts / Gemini payloads can present a macro as a JSON number OR a numeric
// string ("536"); missing/garbage → 0, or nil for the optional variant.
enum LenientNumber {
  static func double<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double {
    optionalDouble(c, key) ?? 0
  }

  static func optionalDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    if let s = try? c.decodeIfPresent(String.self, forKey: key) { return NumberParsing.double(s) }
    return nil
  }
}
