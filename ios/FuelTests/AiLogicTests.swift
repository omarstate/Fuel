import Testing
import Foundation
@testable import Fuel

// Pure-logic ports for the M4 AI flows: the remaining-macros clamp + suggestion
// cache bucket-key, and the estimate-row → LoggedMeal conversion (rounding, meal
// type, usable-row rule, catalog dedupe).
@Suite("AI logic")
struct AiLogicTests {

  // MARK: - Remaining macros clamp

  @Test("clamp is target − consumed, floored at 0")
  func clampNormal() {
    let targets = Targets(calories: 2200, protein: 165, carbs: 220, fat: 70)
    let totals = LoggedMeal.Totals(calories: 800, protein: 60, carbs: 90, fat: 20)
    let r = RemainingMacros.clamp(targets: targets, totals: totals)
    #expect(r.calories == 1400)
    #expect(r.protein == 105)
    #expect(r.carbs == 130)
    #expect(r.fat == 50)
  }

  @Test("clamp floors negatives at 0 when over target")
  func clampFloors() {
    let targets = Targets(calories: 2200, protein: 165, carbs: 220, fat: 70)
    let totals = LoggedMeal.Totals(calories: 2600, protein: 200, carbs: 240, fat: 90)
    let r = RemainingMacros.clamp(targets: targets, totals: totals)
    #expect(r.calories == 0)
    #expect(r.protein == 0)
    #expect(r.carbs == 0)
    #expect(r.fat == 0)
  }

  @Test("clamp caps at the server ceilings")
  func clampCaps() {
    let targets = Targets(calories: 12000, protein: 900, carbs: 1500, fat: 600)
    let totals = LoggedMeal.Totals()
    let r = RemainingMacros.clamp(targets: targets, totals: totals)
    #expect(r.calories == RemainingMacros.maxCalories) // 8000
    #expect(r.protein == RemainingMacros.maxProtein)   // 600
    #expect(r.carbs == RemainingMacros.maxCarbs)       // 1000
    #expect(r.fat == RemainingMacros.maxFat)           // 400
  }

  // MARK: - Bucket key

  @Test("bucketKey floors each macro into its bucket and appends lang")
  func bucketKey() {
    let r = RemainingMacros(calories: 1450, protein: 108, carbs: 133, fat: 52)
    // 1450/100=14, 108/10=10, 133/15=8, 52/10=5
    #expect(r.bucketKey(lang: "en") == "14|10|8|5|en")
    #expect(r.bucketKey(lang: "ar") == "14|10|8|5|ar")
  }

  @Test("nearby remaining states share a bucket key")
  func bucketKeyStable() {
    // Both fall in cal 14 (1400–1499), protein 10 (100–109), carbs 8 (120–134),
    // fat 5 (50–59).
    let a = RemainingMacros(calories: 1400, protein: 100, carbs: 120, fat: 50)
    let b = RemainingMacros(calories: 1499, protein: 109, carbs: 134, fat: 59)
    #expect(a.bucketKey(lang: "en") == b.bucketKey(lang: "en"))
  }

  // MARK: - Estimate row conversion

  @Test("EstimateRow(from:) rounds double macros to integer strings")
  func rowRounding() {
    let estimate = EstimatedMeal(
      input: "koshari", ok: true, name: "Koshari", servingSize: "1 plate",
      calories: 718.6, protein: 21.4, carbs: 119.9, fat: 13.5,
      source: .egypt, confidence: .high, note: "Street portion"
    )
    let row = EstimateRow(from: estimate)
    #expect(row.calories == "719")   // 718.6 → 719
    #expect(row.protein == "21")     // 21.4 → 21
    #expect(row.carbs == "120")      // 119.9 → 120
    #expect(row.fat == "14")         // 13.5 → 14
    #expect(row.caloriesValue == 719)
  }

  @Test("usable-row rule: ok || (name non-empty && calories > 0)")
  func usableRule() {
    // ok true → usable regardless of edits
    let okRow = EstimateRow(input: "x", name: "Anything", servingSize: "",
                            calories: "0", protein: "0", carbs: "0", fat: "0", ok: true)
    #expect(okRow.isUsable == true)

    // ok false but hand-filled name + calories → usable
    let filled = EstimateRow(input: "x", name: "Homemade dish", servingSize: "",
                             calories: "350", protein: "20", carbs: "30", fat: "10", ok: false)
    #expect(filled.isUsable == true)

    // ok false, no name → not usable
    let noName = EstimateRow(input: "x", name: "  ", servingSize: "",
                             calories: "350", protein: "0", carbs: "0", fat: "0", ok: false)
    #expect(noName.isUsable == false)

    // ok false, name but zero calories → not usable
    let noKcal = EstimateRow(input: "x", name: "Mystery", servingSize: "",
                             calories: "0", protein: "0", carbs: "0", fat: "0", ok: false)
    #expect(noKcal.isUsable == false)
  }

  @Test("loggedMeal converts a usable row with the chosen meal type")
  func loggedMealConversion() {
    let userID = UUID()
    let at = Date(timeIntervalSince1970: 1_700_000_000)
    let row = EstimateRow(input: "koshari", name: "Koshari", servingSize: "1 plate",
                          calories: "720", protein: "22", carbs: "120", fat: "14", ok: true)
    let meal = row.loggedMeal(userId: userID, mealType: .dinner, loggedAt: at)
    #expect(meal != nil)
    #expect(meal?.userId == userID)
    #expect(meal?.mealType == .dinner)
    #expect(meal?.name == "Koshari")
    #expect(meal?.servingSize == "1 plate")
    #expect(meal?.calories == 720)
    #expect(meal?.protein == 22)
    #expect(meal?.loggedAt == at)
    #expect(meal?.catalogMealId == nil)
  }

  @Test("loggedMeal returns nil for an unusable row and empty serving becomes nil")
  func loggedMealNilAndServing() {
    let unusable = EstimateRow(input: "x", name: "", servingSize: "",
                               calories: "0", protein: "0", carbs: "0", fat: "0", ok: false)
    #expect(unusable.loggedMeal(userId: UUID(), mealType: .snack, loggedAt: Date()) == nil)

    let noServing = EstimateRow(input: "eggs", name: "Eggs", servingSize: "   ",
                                calories: "150", protein: "12", carbs: "1", fat: "10", ok: true)
    let meal = noServing.loggedMeal(userId: UUID(), mealType: .breakfast, loggedAt: Date())
    #expect(meal?.servingSize == nil)
  }

  @Test("dedupedCatalogInputs keeps only usable rows, deduped by lowercased name")
  func catalogDedupe() {
    let rows = [
      EstimateRow(input: "a", name: "Koshari", servingSize: "", calories: "700", protein: "20", carbs: "110", fat: "12", ok: true),
      EstimateRow(input: "b", name: "koshari", servingSize: "", calories: "710", protein: "21", carbs: "112", fat: "13", ok: true),
      EstimateRow(input: "c", name: "", servingSize: "", calories: "0", protein: "0", carbs: "0", fat: "0", ok: false),
      EstimateRow(input: "d", name: "Tea", servingSize: "", calories: "40", protein: "0", carbs: "9", fat: "0", ok: true),
    ]
    let inputs = rows.dedupedCatalogInputs()
    #expect(inputs.count == 2)                 // Koshari (first) + Tea; dup + unusable dropped
    #expect(inputs.map(\.name) == ["Koshari", "Tea"])
  }
}
