import Foundation

// POST /meals/photo-extract -> ExtractedLabel. Gemini reads a photographed
// nutrition-facts panel into structured macros on a stated basis. Slow (vision,
// 10–40s). `ok == false` / `readable == false` is a SOFT failure (blurry / not
// a label) — offer retake or manual entry, never an error. Conforms to
// `LabelSource` so it drives the shared review/scale flow. Macros decode
// leniently, matching the AI endpoints.
struct ExtractedLabel: Decodable, Equatable, Sendable, LabelSource {
  let ok: Bool
  let readable: Bool
  let name: String?
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
    case ok, readable, name, basis, servingSize, servingGrams
    case calories, protein, carbs, fat, confidence, note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    readable = try c.decodeIfPresent(Bool.self, forKey: .readable) ?? false
    name = try c.decodeIfPresent(String.self, forKey: .name)
    basis = (try? c.decodeIfPresent(LabelBasis.self, forKey: .basis)) ?? .perServing
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
    ok: Bool, readable: Bool, name: String?, basis: LabelBasis,
    servingSize: String, servingGrams: Double?,
    calories: Double, protein: Double, carbs: Double, fat: Double,
    confidence: LabelConfidence?, note: String
  ) {
    self.ok = ok
    self.readable = readable
    self.name = name
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

// POST /meals/photo-extract body. Raw base64 (no data: prefix) + MIME type.
struct PhotoExtractBody: Encodable, Sendable {
  let image: String
  let mimeType: String
}
