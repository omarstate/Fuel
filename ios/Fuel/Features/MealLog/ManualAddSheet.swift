import SwiftUI

// Manual meal entry: name, meal-type segment (pre-selected by time of day),
// optional serving size, and the four macros on decimal pads with a Done
// keyboard toolbar and a focus chain. Save runs the injected async action
// (insert → optimistic list update), fires a success haptic, and dismisses.
struct ManualAddSheet: View {
  /// Persist the meal. Throws to keep the sheet open and surface an error.
  let onSave: (NewMeal) async throws -> Void
  /// Section to preselect (e.g. tapping "+ Add" on an empty Today section);
  /// falls back to the time-of-day suggestion.
  var preselectedType: MealType? = nil

  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var mealType = MealTypeSuggestion.suggested()
  @State private var servingSize = ""
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""
  @State private var error: PresentableError?

  @FocusState private var focus: Field?

  private enum Field: Hashable { case name, serving, calories, protein, carbs, fat }

  // Parsed, validated payload the sheet hands back on save.
  struct NewMeal {
    let name: String
    let mealType: MealType
    let servingSize: String?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var parsedCalories: Int? { NumberParsing.int(calories) }
  private var isValid: Bool { !trimmedName.isEmpty && (parsedCalories ?? -1) >= 0 }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Meal name", text: $name)
            .focused($focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { focus = .serving }
          Picker("Section", selection: $mealType) {
            ForEach(MealType.allCases) { type in
              Text(type.label).tag(type)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("Serving") {
          TextField("e.g. 1 plate (450g) — optional", text: $servingSize)
            .focused($focus, equals: .serving)
        }

        Section("Nutrition") {
          macroField("Calories", text: $calories, unit: "kcal", field: .calories, ink: MacroPalette.caloriesInk)
          macroField("Protein", text: $protein, unit: "g", field: .protein, ink: MacroPalette.proteinInk)
          macroField("Carbs", text: $carbs, unit: "g", field: .carbs, ink: MacroPalette.carbsInk)
          macroField("Fat", text: $fat, unit: "g", field: .fat, ink: MacroPalette.fatInk)
        }

        if let error {
          Section {
            ErrorBanner(error: error, onDismiss: { self.error = nil })
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Log meal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          AsyncButton("Save", style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
            try await save()
          } onError: { err in
            error = PresentableError(err)
          }
          .disabled(!isValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focus = nil }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .onAppear {
      if let preselectedType { mealType = preselectedType }
    }
  }

  private func macroField(
    _ label: LocalizedStringKey,
    text: Binding<String>,
    unit: String,
    field: Field,
    ink: Color
  ) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: text)
        .keyboardType(.decimalPad)
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

  private func save() async throws {
    guard isValid, let kcal = parsedCalories else {
      throw APIError.server(message: String(localized: "Add a name and calories."), status: 400)
    }
    let serving = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
    try await onSave(
      NewMeal(
        name: trimmedName,
        mealType: mealType,
        servingSize: serving.isEmpty ? nil : serving,
        calories: kcal,
        protein: NumberParsing.int(protein) ?? 0,
        carbs: NumberParsing.int(carbs) ?? 0,
        fat: NumberParsing.int(fat) ?? 0
      )
    )
    dismiss()
  }
}

#Preview {
  ManualAddSheet { _ in try? await Task.sleep(for: .seconds(1)) }
}
