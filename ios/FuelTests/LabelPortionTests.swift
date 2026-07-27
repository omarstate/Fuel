import Testing
import Foundation
@testable import Fuel

// Ports the exact web semantics of frontend/src/app-editorial/label-portion.ts:
// gramsPerUnit per basis, grams↔servings sync in both directions with identical
// rounding, toReview default portions, eatenText strings, toCatalogBase per-100g
// normalization (+ nil on non-positive calories), and parseServingGrams including
// the Egypt-first Arabic units.
@Suite("LabelPortion")
struct LabelPortionTests {

  // A per-serving label whose serving is a known 50 g, base = per-serving macros.
  private func perServing50() -> ExtractedLabel {
    ExtractedLabel(
      ok: true, readable: true, name: "Bar", basis: .perServing,
      servingSize: "1 bar (50 g)", servingGrams: 50,
      calories: 100, protein: 10, carbs: 8, fat: 4, confidence: .high, note: ""
    )
  }

  // MARK: - gramsPerUnit

  @Test("gramsPerUnit: per_100g is always 100; per_serving is the serving grams")
  func gramsPerUnit() {
    #expect(LabelPortion.gramsPerUnit(basis: .per100g, servingGrams: nil) == 100)
    #expect(LabelPortion.gramsPerUnit(basis: .per100g, servingGrams: 30) == 100)
    #expect(LabelPortion.gramsPerUnit(basis: .perServing, servingGrams: 45) == 45)
    #expect(LabelPortion.gramsPerUnit(basis: .perServing, servingGrams: nil) == nil)
  }

  // MARK: - toReview defaults

  @Test("toReview: per_100g without a serving size defaults to 100 g at factor 1")
  func toReviewPer100Default() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Oats", basis: .per100g,
      servingSize: "", servingGrams: nil,
      calories: 250, protein: 12, carbs: 40, fat: 6, confidence: nil, note: ""
    )
    let r = LabelPortion.toReview(label)
    #expect(r.grams == "100")
    #expect(r.servings == "1")
    #expect(r.calories == "250") // factor 1
    #expect(r.protein == "12")
  }

  @Test("toReview: per_100g with a serving size seeds grams from it")
  func toReviewPer100WithServing() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Chips", basis: .per100g,
      servingSize: "1 bag (30 g)", servingGrams: 30,
      calories: 536, protein: 7, carbs: 53, fat: 33, confidence: nil, note: ""
    )
    let r = LabelPortion.toReview(label)
    #expect(r.grams == "30")
    #expect(r.calories == "161") // round(536 * 0.30)
  }

  @Test("toReview: per_serving with a known serving size seeds one serving in grams")
  func toReviewPerServingWithGrams() {
    let r = LabelPortion.toReview(perServing50())
    #expect(r.grams == "50")
    #expect(r.servings == "1")
    #expect(r.calories == "100") // factor 50/50 = 1
  }

  @Test("toReview: per_serving without a serving size has no grams control")
  func toReviewPerServingNoGrams() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Soup", basis: .perServing,
      servingSize: "", servingGrams: nil,
      calories: 120, protein: 5, carbs: 15, fat: 3, confidence: nil, note: ""
    )
    let r = LabelPortion.toReview(label)
    #expect(r.grams == "")
    #expect(r.servings == "1")
    #expect(LabelPortion.canUseGrams(r) == false)
    #expect(r.calories == "120")
  }

  // MARK: - applyPortion sync (grams authoritative)

  @Test("applyPortion: editing grams derives servings and rescales")
  func applyGramsDerivesServings() {
    let r0 = LabelPortion.toReview(perServing50())
    let r = LabelPortion.applyPortion(r0, grams: "100")
    #expect(r.grams == "100")
    #expect(r.servings == "2")   // 100 / 50
    #expect(r.calories == "200") // round(100 * 2)
    #expect(r.protein == "20")
  }

  @Test("applyPortion: editing servings derives grams and rescales")
  func applyServingsDerivesGrams() {
    let r0 = LabelPortion.toReview(perServing50())
    let r = LabelPortion.applyPortion(r0, servings: "0.5")
    #expect(r.grams == "25")    // round(0.5 * 50)
    #expect(r.servings == "0.5")
    #expect(r.calories == "50") // round(100 * 0.5)
  }

  @Test("applyPortion: clearing grams blanks servings and zeroes the totals")
  func applyEmptyGrams() {
    let r0 = LabelPortion.toReview(perServing50())
    let r = LabelPortion.applyPortion(r0, grams: "")
    #expect(r.servings == "")
    #expect(r.calories == "0")
  }

  // MARK: - eatenText

  @Test("eatenText: grams basis reports the grams eaten")
  func eatenGrams() {
    var r = LabelPortion.toReview(perServing50())
    r = LabelPortion.applyPortion(r, grams: "150")
    #expect(LabelPortion.eatenText(r) == "150 g")
  }

  @Test("eatenText: empty grams falls back to the printed serving size")
  func eatenGramsEmpty() {
    var r = LabelPortion.toReview(perServing50())
    r = LabelPortion.applyPortion(r, grams: "")
    #expect(LabelPortion.eatenText(r) == "1 bar (50 g)")
  }

  @Test("eatenText: servings basis with a serving size uses n × size")
  func eatenServingsWithSize() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Bar", basis: .perServing,
      servingSize: "1 bar", servingGrams: nil,
      calories: 100, protein: 10, carbs: 8, fat: 4, confidence: nil, note: ""
    )
    var r = LabelPortion.toReview(label)
    r = LabelPortion.applyPortion(r, servings: "2")
    #expect(LabelPortion.eatenText(r) == "2 × 1 bar")
  }

  @Test("eatenText: servings basis without a size pluralizes")
  func eatenServingsNoSize() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Soup", basis: .perServing,
      servingSize: "", servingGrams: nil,
      calories: 120, protein: 5, carbs: 15, fat: 3, confidence: nil, note: ""
    )
    let one = LabelPortion.toReview(label)
    #expect(LabelPortion.eatenText(one) == "1 serving")
    let two = LabelPortion.applyPortion(one, servings: "2")
    #expect(LabelPortion.eatenText(two) == "2 servings")
  }

  // MARK: - toCatalogBase

  @Test("toCatalogBase: a grams basis normalizes to per 100 g")
  func catalogPer100Norm() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Oats", basis: .per100g,
      servingSize: "", servingGrams: nil,
      calories: 250, protein: 12, carbs: 40, fat: 6, confidence: nil, note: ""
    )
    var r = LabelPortion.toReview(label)
    r = LabelPortion.applyPortion(r, grams: "200") // factor 2, totals doubled
    let base = LabelPortion.toCatalogBase(r)
    #expect(base?.servingSize == "100 g")
    #expect(base?.calories == 250) // recovered back to per-100g
    #expect(base?.protein == 12)
  }

  @Test("toCatalogBase: a per-serving basis keeps its serving values")
  func catalogPerServing() {
    let label = ExtractedLabel(
      ok: true, readable: true, name: "Bar", basis: .perServing,
      servingSize: "1 bar", servingGrams: nil,
      calories: 100, protein: 10, carbs: 8, fat: 4, confidence: nil, note: ""
    )
    var r = LabelPortion.toReview(label)
    r = LabelPortion.applyPortion(r, servings: "2")
    let base = LabelPortion.toCatalogBase(r)
    #expect(base?.servingSize == "1 bar")
    #expect(base?.calories == 100) // recovered per-serving
    #expect(base?.protein == 10)
  }

  @Test("toCatalogBase: non-positive calories skip the save")
  func catalogNilOnZero() {
    let r = LabelPortion.manualReview() // per-serving, all zeros
    #expect(LabelPortion.toCatalogBase(r) == nil)
  }

  // MARK: - parseServingGrams

  @Test("parseServingGrams: plain metric units")
  func parseMetric() {
    #expect(LabelPortion.parseServingGrams("330 ml") == 330)
    #expect(LabelPortion.parseServingGrams("2 x 125g") == 125) // first number+unit
    #expect(LabelPortion.parseServingGrams("(250g)") == 250)
    #expect(LabelPortion.parseServingGrams("1 cup (240 ml)") == 240) // parenthesized wins
    #expect(LabelPortion.parseServingGrams("500 ml") == 500)
  }

  @Test("parseServingGrams: kg and l scale x1000")
  func parseKiloUnits() {
    #expect(LabelPortion.parseServingGrams("1.5 kg") == 1500)
    #expect(LabelPortion.parseServingGrams("1 l") == 1000)
  }

  @Test("parseServingGrams: Arabic units and Arabic-Indic digits")
  func parseArabic() {
    #expect(LabelPortion.parseServingGrams("250 جرام") == 250)
    #expect(LabelPortion.parseServingGrams("٢٥٠ جم") == 250)  // Arabic-Indic digits
    #expect(LabelPortion.parseServingGrams("1 كجم") == 1000)  // kg ×1000
  }

  @Test("parseServingGrams: rejects non-units and empty input")
  func parseRejects() {
    #expect(LabelPortion.parseServingGrams("1 large") == nil)
    #expect(LabelPortion.parseServingGrams("") == nil)
    #expect(LabelPortion.parseServingGrams(nil) == nil)
  }
}
