import Foundation

// The editable review row for one AI estimate. Numeric fields are strings so the
// decimal-pad inputs stay controlled while the user tweaks them, exactly like
// the web's `Row`. Pure Foundation (no SwiftUI/Supabase) so the usable-row rule
// and the LoggedMeal / catalog conversions are unit-tested; the view uses it
// directly as `$rows[i].name`-style binding state.
struct EstimateRow: Identifiable, Equatable, Sendable {
  let id = UUID()
  let input: String
  var name: String
  var servingSize: String
  var calories: String
  var protein: String
  var carbs: String
  var fat: String
  let source: EstimatedMeal.Source?
  let confidence: EstimatedMeal.Confidence?
  let note: String
  let ok: Bool

  init(from e: EstimatedMeal) {
    input = e.input
    name = e.name
    servingSize = e.servingSize
    calories = Self.intString(e.calories)
    protein = Self.intString(e.protein)
    carbs = Self.intString(e.carbs)
    fat = Self.intString(e.fat)
    source = e.source
    confidence = e.confidence
    note = e.note
    ok = e.ok
  }

  // Direct init for previews/tests.
  init(
    input: String, name: String, servingSize: String,
    calories: String, protein: String, carbs: String, fat: String,
    source: EstimatedMeal.Source? = nil, confidence: EstimatedMeal.Confidence? = nil,
    note: String = "", ok: Bool = true
  ) {
    self.input = input
    self.name = name
    self.servingSize = servingSize
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.source = source
    self.confidence = confidence
    self.note = note
    self.ok = ok
  }

  // Round a possibly-double estimate to a whole-number string for display.
  private static func intString(_ value: Double) -> String {
    String(Int(value.rounded()))
  }

  var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  var caloriesValue: Int { NumberParsing.int(calories) ?? 0 }
  var proteinValue: Int { NumberParsing.int(protein) ?? 0 }
  var carbsValue: Int { NumberParsing.int(carbs) ?? 0 }
  var fatValue: Int { NumberParsing.int(fat) ?? 0 }

  /// Includable in the log: an AI-usable row, OR a hand-filled row (a soft
  /// failure the user gave a name and calories). Mirrors the milestone rule
  /// `ok || (name non-empty && calories > 0)`.
  var isUsable: Bool {
    ok || (!trimmedName.isEmpty && caloriesValue > 0)
  }

  private var loggedServingSize: String? {
    let s = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
    return s.isEmpty ? nil : s
  }

  private var loggedName: String {
    trimmedName.isEmpty ? input : trimmedName
  }

  /// Build a personal-log entry for the signed-in user, or nil if not usable.
  /// Macros floor at 0.
  func loggedMeal(userId: UUID, mealType: MealType, loggedAt: Date) -> LoggedMeal? {
    guard isUsable else { return nil }
    return LoggedMeal(
      userId: userId,
      name: loggedName,
      mealType: mealType,
      servingSize: loggedServingSize,
      calories: max(caloriesValue, 0),
      protein: max(proteinValue, 0),
      carbs: max(carbsValue, 0),
      fat: max(fatValue, 0),
      loggedAt: loggedAt
    )
  }

  /// Best-effort shared-catalog contribution, or nil if not usable.
  func catalogInput() -> AiCatalogMealInput? {
    guard isUsable else { return nil }
    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    return AiCatalogMealInput(
      name: loggedName,
      description: trimmedNote.isEmpty ? nil : trimmedNote,
      servingSize: loggedServingSize,
      calories: max(caloriesValue, 0),
      protein: max(proteinValue, 0),
      carbs: max(carbsValue, 0),
      fat: max(fatValue, 0)
    )
  }
}

extension Array where Element == EstimateRow {
  /// The usable rows' catalog inputs, deduped by lowercased name (first wins).
  func dedupedCatalogInputs() -> [AiCatalogMealInput] {
    var seen = Set<String>()
    var result: [AiCatalogMealInput] = []
    for row in self {
      guard let input = row.catalogInput() else { continue }
      let key = input.name.lowercased()
      if seen.insert(key).inserted {
        result.append(input)
      }
    }
    return result
  }
}
