import SwiftUI

// Manual daily-goal editing, pushed from the More tab's "Daily goal" tile.
// The four targets are normally server-computed from the BMR details; this
// screen writes direct overrides via PUT /profile/targets. The recommended
// numbers stay one tap away, and the details-edit contract (saving details
// recomputes targets) is spelled out in the footnote.
struct DailyGoalsView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss

  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""
  @State private var error: PresentableError?
  @FocusState private var focus: Field?
  private enum Field: Hashable { case calories, protein, carbs, fat }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Set the daily calories and macros Fuel tracks against. Numbers are up to you — the recommendation below comes from your details.")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)

        if let error {
          ErrorBanner(error: error, onDismiss: { self.error = nil })
        }

        fieldsCard

        if let hint = boundsHint {
          Text(hint)
            .font(.fuelBody(.caption))
            .foregroundStyle(Color.fuelDestructive)
        }

        recommendedCard

        AsyncButton("Save goals", successHaptic: true) {
          try await save()
        } onError: { err in
          error = PresentableError(err)
        }
        .disabled(!canSave)
        .frame(maxWidth: .infinity)
        .controlSize(.large)

        Text("Editing your details in Profile recalculates these automatically.")
          .font(.fuelBody(.caption))
          .foregroundStyle(Color.fuelSubtle)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
      }
      .padding(20)
    }
    .background(Color.fuelBackground)
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Daily goals")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focus = nil }
      }
    }
    .onAppear { prefill() }
  }

  // MARK: - Fields

  private var fieldsCard: some View {
    VStack(spacing: 14) {
      goalField("Calories", text: $calories, unit: "kcal", field: .calories, ink: MacroPalette.caloriesInk)
      Divider().overlay(Color.fuelInk.opacity(0.06))
      goalField("Protein", text: $protein, unit: "g", field: .protein, ink: MacroPalette.proteinInk)
      Divider().overlay(Color.fuelInk.opacity(0.06))
      goalField("Carbs", text: $carbs, unit: "g", field: .carbs, ink: MacroPalette.carbsInk)
      Divider().overlay(Color.fuelInk.opacity(0.06))
      goalField("Fat", text: $fat, unit: "g", field: .fat, ink: MacroPalette.fatInk)
    }
    .padding(18)
    .fuelCard()
  }

  private func goalField(
    _ label: LocalizedStringKey,
    text: Binding<String>,
    unit: String,
    field: Field,
    ink: Color
  ) -> some View {
    HStack {
      Text(label)
        .font(.fuelBody(.body, weight: 500))
        .foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: text)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .font(.fuelMono(.body))
        .focused($focus, equals: field)
        .frame(maxWidth: 90)
      Text(unit)
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(ink)
        .frame(width: 34, alignment: .leading)
    }
  }

  // MARK: - Recommended

  /// The server's formula, mirrored client-side for display (TargetMath is the
  /// tested port of compute-targets.js).
  private var recommended: Targets? {
    guard let p = app.profile else { return nil }
    return TargetMath.computeTargets(TargetMath.Input(
      sex: p.sex, age: Double(p.age), heightCm: p.heightCm, weightKg: p.weightKg,
      goalWeightKg: p.goalWeightKg, activityLevel: p.activityLevel, pace: p.pace
    ))
  }

  @ViewBuilder
  private var recommendedCard: some View {
    if let rec = recommended {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Recommended for you").fuelEyebrow()
          Text("\(rec.calories) kcal · P \(rec.protein) · C \(rec.carbs) · F \(rec.fat)")
            .font(.fuelMono(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelInk)
        }
        Spacer()
        if input != FuelAPI.TargetsInput(calories: rec.calories, protein: rec.protein,
                                         carbs: rec.carbs, fat: rec.fat) {
          Button("Use") { apply(rec) }
            .buttonStyle(.glass)
            .controlSize(.small)
            .tint(.fuelCitrus)
        }
      }
      .padding(16)
      .fuelCard()
    }
  }

  private func apply(_ t: Targets) {
    withAnimation(.snappy) {
      calories = String(t.calories)
      protein = String(t.protein)
      carbs = String(t.carbs)
      fat = String(t.fat)
    }
  }

  // MARK: - Validation + save

  /// Mirrors the backend's zod bounds so errors surface before the round-trip.
  private static let calorieRange = 800...10_000
  private static let proteinRange = 10...500
  private static let carbsRange = 0...1_000
  private static let fatRange = 0...500

  private var input: FuelAPI.TargetsInput? {
    guard let kcal = Int(calories), let p = Int(protein),
          let c = Int(carbs), let f = Int(fat) else { return nil }
    return FuelAPI.TargetsInput(calories: kcal, protein: p, carbs: c, fat: f)
  }

  private var inputInBounds: Bool {
    guard let input else { return false }
    return Self.calorieRange.contains(input.calories)
      && Self.proteinRange.contains(input.protein)
      && Self.carbsRange.contains(input.carbs)
      && Self.fatRange.contains(input.fat)
  }

  private var boundsHint: LocalizedStringKey? {
    guard let input else { return nil }
    if !Self.calorieRange.contains(input.calories) { return "Calories must be between 800 and 10,000." }
    if !Self.proteinRange.contains(input.protein) { return "Protein must be between 10 and 500 g." }
    if !Self.carbsRange.contains(input.carbs) { return "Carbs must be between 0 and 1,000 g." }
    if !Self.fatRange.contains(input.fat) { return "Fat must be between 0 and 500 g." }
    return nil
  }

  private var unchanged: Bool {
    guard let input else { return false }
    let t = app.targets
    return input == FuelAPI.TargetsInput(calories: t.calories, protein: t.protein,
                                         carbs: t.carbs, fat: t.fat)
  }

  private var canSave: Bool { inputInBounds && !unchanged }

  private func prefill() {
    let t = app.targets
    calories = String(t.calories)
    protein = String(t.protein)
    carbs = String(t.carbs)
    fat = String(t.fat)
  }

  private func save() async throws {
    guard let input else { return }
    let saved = try await FuelAPI.saveTargets(input)
    app.applyProfile(saved)
    dismiss()
  }
}

#Preview {
  NavigationStack { DailyGoalsView() }
    .environment(AppState())
}
