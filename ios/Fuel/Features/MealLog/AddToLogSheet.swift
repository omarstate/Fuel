import SwiftUI

// Logs a catalog meal to the personal log. Presents a meal-type section picker
// (the time-of-day suggestion first, tagged "Suggested" — never hardcoded), a
// serving multiplier stepper (0.5×–3×) that scales the macros live, and a
// primary Log button. When the meal's serving size carries a weight ("100 g",
// "1 plate (450g)", Arabic digits included — parsed by
// LabelPortion.parseServingGrams), a "Grams eaten" field appears as the second
// way to size the portion: type the exact grams and every macro rescales by
// grams ÷ serving-grams. The two inputs stay in sync (stepping servings
// rewrites the grams; typing grams moves the multiplier). Writes straight to
// MealLogRepository with the catalog meal id attached, then dismisses. Shared
// by meal detail and Library rows.
struct AddToLogSheet: View {
  let meal: CatalogMeal
  /// Section to preselect (e.g. logging from the Add-meal panel, which is already
  /// scoped to one section); falls back to the time-of-day suggestion.
  var preselectedType: MealType?
  /// Fired after a successful log, before dismissal (e.g. to nudge a refresh).
  var onLogged: () -> Void = {}

  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  @State private var mealType: MealType
  @State private var factor: Double = 1
  @State private var gramsText: String
  /// True while the grams field was the last portion input — the logged
  /// serving string then records the grams ("230 g") instead of a multiplier.
  @State private var usedGramsEntry = false
  @State private var error: PresentableError?
  @FocusState private var gramsFocused: Bool

  /// The meal's base weight per serving, parsed from its serving-size text
  /// ("1 bowl (250 g)" → 250). nil when the serving carries no weight — the
  /// sheet then offers the multiplier stepper alone, as before.
  private let servingGrams: Double?

  init(meal: CatalogMeal, preselectedType: MealType? = nil, onLogged: @escaping () -> Void = {}) {
    self.meal = meal
    self.preselectedType = preselectedType
    self.onLogged = onLogged
    _mealType = State(initialValue: preselectedType ?? MealTypeSuggestion.suggested())
    let grams = LabelPortion.parseServingGrams(meal.servingSize)
    self.servingGrams = grams
    _gramsText = State(initialValue: grams.map { LabelPortion.numberString($0) } ?? "")
  }

  private let repo = MealLogRepository()
  private let suggested = MealTypeSuggestion.suggested()

  private let minFactor: Double = 0.5
  private let maxFactor: Double = 3

  // Suggested section first, then the rest in canonical order.
  private var sectionOrder: [MealType] {
    [suggested] + MealTypeSuggestion.order.filter { $0 != suggested }
  }

  private var scaled: PortionScaling.Macros {
    PortionScaling.macros(
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fat: meal.fat,
      factor: factor
    )
  }

  // Serving text stored on the log entry: the exact grams when the grams field
  // sized the portion, otherwise the serving annotated with the multiplier
  // when ≠1×.
  private var loggedServingSize: String? {
    if usedGramsEntry, servingGrams != nil, factor > 0 {
      let g = gramsText.trimmingCharacters(in: .whitespaces)
      if !g.isEmpty { return "\(g) g" }
    }
    let base = meal.servingSize?.trimmingCharacters(in: .whitespaces)
    let isWhole = factor == 1
    if let base, !base.isEmpty {
      return isWhole ? base : "\(PortionScaling.factorLabel(factor))× \(base)"
    }
    return isWhole ? nil : "\(PortionScaling.factorLabel(factor)) servings"
  }

  /// Log needs a real portion — typing the grams away (empty/0) zeroes the
  /// factor and disables the button until a portion exists again.
  private var canLog: Bool { factor > 0 }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          summaryRow
        }

        Section("Section") {
          ForEach(sectionOrder) { type in
            Button {
              mealType = type
            } label: {
              HStack {
                Text(type.label)
                  .foregroundStyle(Color.fuelInk)
                if type == suggested {
                  PillBadge(title: "Suggested", tone: .citrus)
                }
                Spacer()
                if type == mealType {
                  Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.fuelCitrusInk)
                }
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }

        Section {
          portionStepper
          if servingGrams != nil {
            gramsRow
          }
          macroPreview
        } header: {
          Text("Servings")
        } footer: {
          if let sg = servingGrams {
            Text("1 serving = \(LabelPortion.numberString(sg)) g. Step servings, or type the exact grams you ate — the nutrition rescales from the serving's facts.")
          }
        }

        if let error {
          Section {
            ErrorBanner(error: error, onDismiss: { self.error = nil })
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }
      }
      .navigationTitle("Log to today")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          AsyncButton("Log", style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
            try await log()
          } onError: { err in
            error = PresentableError(err)
          }
          .disabled(!canLog)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { gramsFocused = false }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  // MARK: - Pieces

  private var summaryRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(meal.name)
        .font(.fuelHeading(.headline))
        .foregroundStyle(Color.fuelInk)
      if let serving = meal.servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty {
        Text(serving)
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
      }
    }
  }

  private var portionStepper: some View {
    HStack {
      Text("Servings")
        .foregroundStyle(Color.fuelInk)
      Spacer()
      HStack(spacing: 14) {
        stepButton(systemName: "minus", disabled: factor <= minFactor) {
          setFactor(max(minFactor, factor - 0.5))
        }
        Text("\(PortionScaling.factorLabel(factor))×")
          .font(.fuelMono(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .frame(minWidth: 44)
          .contentTransition(.numericText())
        stepButton(systemName: "plus", disabled: factor >= maxFactor) {
          setFactor(min(maxFactor, factor + 0.5))
        }
      }
    }
  }

  // The base-unit escape hatch: type what the scale said. Editing this drives
  // the factor (grams ÷ serving-grams); stepping servings rewrites it back.
  private var gramsRow: some View {
    HStack {
      Text("Grams eaten")
        .foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: gramsBinding)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body))
        .focused($gramsFocused)
        .frame(maxWidth: 90)
      Text("g")
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(Color.fuelSubtle)
        .frame(width: 20, alignment: .leading)
    }
  }

  /// Stepper path: set the multiplier and derive the grams from it.
  private func setFactor(_ f: Double) {
    factor = f
    usedGramsEntry = false
    if let sg = servingGrams {
      gramsText = LabelPortion.numberString(f * sg)
    }
  }

  /// Grams path: the field is authoritative — the factor follows it. Blank or
  /// unparseable input zeroes the factor (Log disables) until corrected.
  private var gramsBinding: Binding<String> {
    Binding(
      get: { gramsText },
      set: { text in
        gramsText = text
        guard let sg = servingGrams, sg > 0 else { return }
        usedGramsEntry = true
        let grams = NumberParsing.double(text) ?? 0
        factor = grams.isFinite && grams > 0 ? grams / sg : 0
      }
    )
  }

  private func stepButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.snappy) { action() }
    } label: {
      Image(systemName: systemName)
        .font(.body.weight(.bold))
        .frame(width: 30, height: 30)
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.circle)
    .tint(.fuelCitrus)
    .disabled(disabled)
    .accessibilityLabel(systemName.contains("minus") ? "Fewer servings" : "More servings")
  }

  private var macroPreview: some View {
    HStack(spacing: 4) {
      Text("\(scaled.calories)")
        .foregroundStyle(Color.fuelInk)
      Text("kcal").foregroundStyle(Color.fuelSubtle)
      Text("·").foregroundStyle(Color.fuelSubtle)
      Text("\(scaled.protein)P").foregroundStyle(MacroPalette.proteinInk)
      Text("\(scaled.carbs)C").foregroundStyle(MacroPalette.carbsInk)
      Text("\(scaled.fat)F").foregroundStyle(MacroPalette.fatInk)
    }
    .font(.fuelMono(.subheadline, weight: 500))
    .contentTransition(.numericText())
  }

  // MARK: - Action

  private func log() async throws {
    let userID = try await repo.userID()
    let macros = scaled
    let entry = LoggedMeal(
      userId: userID,
      name: meal.name,
      mealType: mealType,
      servingSize: loggedServingSize,
      calories: macros.calories,
      protein: macros.protein,
      carbs: macros.carbs,
      fat: macros.fat,
      loggedAt: Date(),
      catalogMealId: UUID(uuidString: meal.id)
    )
    try await repo.insert(entry)
    app.bumpLogRevision()
    onLogged()
    dismiss()
  }
}

#Preview {
  AddToLogSheet(meal: CatalogMeal(
    id: UUID().uuidString, name: "Koshari", description: nil, servingSize: "1 plate (450g)",
    calories: 720, protein: 22, carbs: 120, fat: 14,
    category: .init(id: "c", name: "Egyptian", slug: "egyptian"),
    createdBy: "system", createdAt: Date(), aiSource: .official, sourceUrl: nil, macroRanges: nil
  ))
  .environment(AppState())
}
