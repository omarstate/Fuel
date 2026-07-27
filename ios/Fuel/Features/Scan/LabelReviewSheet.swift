import SwiftUI

// The shared portion-review step for both M5 flows (barcode + photo label).
// Given a `Review` from `LabelPortion.toReview`, it lets the user name the
// product, say how much they ate (the control adapts to the label's basis), see
// the scaled macros update live, correct anything by hand, pick a section, and
// log it. On success it writes the personal-log row, fires a success haptic,
// bumps the log revision, best-effort contributes to the shared catalog, then
// dismisses via `onLogged`. Manual entry is always available — every macro field
// is editable — so a not-found barcode or unreadable photo still logs.
struct LabelReviewSheet: View {
  let brand: String?
  /// Called after a successful log, just before this sheet dismisses.
  var onLogged: () -> Void = {}

  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  @State private var review: Review
  @State private var mealType: MealType
  @State private var error: PresentableError?
  @FocusState private var keyboardActive: Bool

  private let repo = MealLogRepository()
  private let suggested = MealTypeSuggestion.suggested()

  init(review: Review, brand: String? = nil, onLogged: @escaping () -> Void = {}) {
    self.brand = brand
    self.onLogged = onLogged
    _review = State(initialValue: review)
    _mealType = State(initialValue: MealTypeSuggestion.suggested())
  }

  private var sectionOrder: [MealType] {
    [suggested] + MealTypeSuggestion.order.filter { $0 != suggested }
  }

  private var canLog: Bool {
    !review.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        headerSection
        portionSection
        macroSection
        sectionPicker

        if let error {
          Section {
            ErrorBanner(error: error, onDismiss: { self.error = nil })
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.fuelBackground)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Review & log")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          AsyncButton("Log meal", style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
            try await log()
          } onError: { err in
            error = PresentableError(err)
          }
          .disabled(!canLog)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { keyboardActive = false }
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  // MARK: - Header

  private var headerSection: some View {
    Section {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          TextField("Name this product", text: $review.name)
            .font(.fuelBody(.body, weight: 500))
            .foregroundStyle(Color.fuelInk)
            .focused($keyboardActive)
          if let brand, !brand.isEmpty {
            Text(brand)
              .font(.fuelBody(.caption))
              .foregroundStyle(Color.fuelSubtle)
          }
        }
        Spacer(minLength: 0)
        if let confidence = review.confidence {
          PillBadge(title: "\(confidence.label)", tone: confidenceTone(confidence))
        }
      }
    } footer: {
      if !review.note.trimmingCharacters(in: .whitespaces).isEmpty {
        Text(review.note)
          .foregroundStyle(review.ok ? Color.fuelSubtle : Color.fuelCitrusInk)
      }
    }
  }

  private func confidenceTone(_ c: LabelConfidence) -> PillBadge.Tone {
    switch c {
    case .high: return .volt
    case .medium: return .neutral
    case .low: return .citrus
    }
  }

  // MARK: - Portion

  @ViewBuilder
  private var portionSection: some View {
    Section {
      if review.servingGrams != nil {
        gramsRow
        servingChips
      } else if review.basis == .per100g {
        gramsRow
        gramPresetChips
      } else {
        servingsStepper
      }
      macroPreview
    } header: {
      Text("How much did you eat?")
    } footer: {
      Text(portionFooter)
    }
  }

  private var gramsRow: some View {
    HStack {
      Text("Grams eaten").foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: gramsBinding)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body))
        .focused($keyboardActive)
        .frame(maxWidth: 90)
      Text("g")
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(Color.fuelSubtle)
        .frame(width: 20, alignment: .leading)
    }
  }

  private var servingChips: some View {
    HStack {
      Text("Servings").foregroundStyle(Color.fuelInk)
      Spacer()
      HStack(spacing: 8) {
        ForEach(Self.servingChips, id: \.value) { chip in
          Chip(label: chip.label, active: matches(review.servings, chip.value)) {
            withAnimation(.snappy) { setServings(chip.value) }
          }
        }
      }
    }
  }

  private var gramPresetChips: some View {
    HStack {
      Text("Quick").foregroundStyle(Color.fuelInk)
      Spacer()
      HStack(spacing: 8) {
        ForEach(Self.gramChips, id: \.self) { g in
          Chip(label: "\(g)", active: matches(review.grams, Double(g))) {
            withAnimation(.snappy) { setGrams(Double(g)) }
          }
        }
      }
    }
  }

  private var servingsStepper: some View {
    HStack {
      Text("Servings").foregroundStyle(Color.fuelInk)
      Spacer()
      HStack(spacing: 14) {
        stepButton("minus", disabled: servingsValue <= 0.5) {
          setServings(max(0.5, servingsValue - 0.5))
        }
        Text(LabelPortion.numberString(servingsValue))
          .font(.fuelMono(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .frame(minWidth: 40)
          .contentTransition(.numericText())
        stepButton("plus", disabled: servingsValue >= 20) {
          setServings(servingsValue + 0.5)
        }
      }
    }
  }

  private var macroPreview: some View {
    HStack(spacing: 6) {
      Text(review.calories).foregroundStyle(Color.fuelInk)
      Text("kcal").foregroundStyle(Color.fuelSubtle)
      Text("·").foregroundStyle(Color.fuelSubtle)
      Text("\(review.protein)P").foregroundStyle(MacroPalette.proteinInk)
      Text("\(review.carbs)C").foregroundStyle(MacroPalette.carbsInk)
      Text("\(review.fat)F").foregroundStyle(MacroPalette.fatInk)
    }
    .font(.fuelMono(.subheadline, weight: 600))
    .contentTransition(.numericText())
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var portionFooter: String {
    if let sg = review.servingGrams {
      let base = "1 serving = \(LabelPortion.numberString(sg)) g"
      return review.servingSize.isEmpty ? "\(base)." : "\(base) · \(review.servingSize)."
    }
    if review.basis == .per100g {
      return String(localized: "Values are per 100 g.")
    }
    if review.servingSize.isEmpty {
      return String(localized: "This label doesn't say how big one serving is — set servings as best you can.")
    }
    return "Values are per serving · \(review.servingSize)."
  }

  // MARK: - Macro fields (manual escape hatch)

  private var macroSection: some View {
    Section {
      macroField("Calories", macro: .calories, unit: "kcal", ink: MacroPalette.caloriesInk)
      macroField("Protein", macro: .protein, unit: "g", ink: MacroPalette.proteinInk)
      macroField("Carbs", macro: .carbs, unit: "g", ink: MacroPalette.carbsInk)
      macroField("Fat", macro: .fat, unit: "g", ink: MacroPalette.fatInk)
    } header: {
      Text("Nutrition")
    } footer: {
      Text("These are the totals that get logged. Edit any value directly if the label reader got it wrong.")
    }
  }

  private func macroField(_ label: LocalizedStringKey, macro: LabelMacro, unit: String, ink: Color) -> some View {
    HStack {
      Text(label).foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: macroBinding(macro))
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body))
        .focused($keyboardActive)
        .frame(maxWidth: 90)
      Text(unit)
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(ink)
        .frame(width: 34, alignment: .leading)
    }
  }

  // MARK: - Section picker

  private var sectionPicker: some View {
    Section("Section") {
      Picker("Section", selection: $mealType) {
        ForEach(sectionOrder) { type in
          Text(type == suggested ? "\(type.label) · Suggested" : type.label).tag(type)
        }
      }
      .pickerStyle(.menu)
      .tint(.fuelCitrusInk)
    }
  }

  // MARK: - Bindings & portion helpers

  private var gramsBinding: Binding<String> {
    Binding(
      get: { review.grams },
      set: { review = LabelPortion.applyPortion(review, grams: $0) }
    )
  }

  private func macroBinding(_ macro: LabelMacro) -> Binding<String> {
    Binding(
      get: { review.value(for: macro) },
      set: { review.setValue($0, for: macro) }
    )
  }

  private func setGrams(_ value: Double) {
    review = LabelPortion.applyPortion(review, grams: LabelPortion.numberString(value))
  }

  private func setServings(_ value: Double) {
    review = LabelPortion.applyPortion(review, servings: LabelPortion.numberString(value))
  }

  private var servingsValue: Double { NumberParsing.double(review.servings) ?? 0 }

  private func matches(_ field: String, _ value: Double) -> Bool {
    guard let n = NumberParsing.double(field) else { return false }
    return abs(n - value) < 0.0001
  }

  private func stepButton(_ systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
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

  // MARK: - Chip constants

  private static let servingChips: [(label: String, value: Double)] = [
    ("½", 0.5), ("1", 1), ("2", 2),
  ]
  private static let gramChips: [Int] = [50, 100, 150, 250]

  // MARK: - Log

  private func log() async throws {
    let name = review.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      throw APIError.server(message: String(localized: "Give this product a name to log it."), status: 400)
    }
    let userID = try await repo.userID()
    let serving = LabelPortion.eatenText(review).trimmingCharacters(in: .whitespaces)
    let entry = LoggedMeal(
      userId: userID,
      name: name,
      mealType: mealType,
      servingSize: serving.isEmpty ? nil : serving,
      calories: max(NumberParsing.int(review.calories) ?? 0, 0),
      protein: max(NumberParsing.int(review.protein) ?? 0, 0),
      carbs: max(NumberParsing.int(review.carbs) ?? 0, 0),
      fat: max(NumberParsing.int(review.fat) ?? 0, 0),
      loggedAt: Date()
    )
    try await repo.insert(entry)
    app.bumpLogRevision()

    // Best-effort: contribute the reviewed product to the shared catalog,
    // normalized to per-100g where possible. Never blocks logging the day.
    if let base = LabelPortion.toCatalogBase(review) {
      let input = AiCatalogMealInput(
        name: name,
        description: review.note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : review.note,
        servingSize: base.servingSize,
        calories: base.calories,
        protein: base.protein,
        carbs: base.carbs,
        fat: base.fat
      )
      _ = try? await FuelAPI.saveAiCatalog(meals: [input])
    }

    onLogged()
    dismiss()
  }
}

// A small selectable pill for the portion shortcuts (½ / 1 / 2 servings,
// 50/100/150/250 g). Citrus when active, quiet otherwise.
private struct Chip: View {
  let label: String
  let active: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.fuelMono(.footnote, weight: 600))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
    .buttonStyle(.plain)
    .foregroundStyle(active ? Color.fuelCitrusInk : Color.fuelSubtle)
    .background(
      Capsule().fill(active ? Color.fuelCitrus.opacity(0.16) : Color.fuelSubtle.opacity(0.12))
    )
  }
}

#Preview("per serving + grams") {
  LabelReviewSheet(
    review: LabelPortion.toReview(BarcodeProduct(
      found: true, ok: true, barcode: "622300", name: "Chipsy Salt", brand: "Chipsy",
      basis: .per100g, servingSize: "1 bag (30 g)", servingGrams: 30,
      calories: 536, protein: 7, carbs: 53, fat: 33, confidence: nil, note: "via Open Food Facts"
    )),
    brand: "Chipsy"
  )
  .environment(AppState())
}
