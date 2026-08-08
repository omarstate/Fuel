import SwiftUI

// Create or edit a shared-catalog meal in one sheet. Fields: name (req),
// category (req), serving size, description, and the four macros on decimal pads
// with a Done keyboard toolbar and a focus chain. Save runs POST or PATCH via
// the API, then hands the result back so the caller can invalidate the Library
// cache and refresh a detail view.
struct CatalogMealForm: View {
  enum Mode: Equatable {
    case create
    case edit(CatalogMeal)
  }

  /// Seed values for create mode — used by the barcode flow to hand a scanned
  /// product over for review before it's saved to the shared catalog. The user
  /// still picks the category (required) and can correct anything.
  struct Prefill: Equatable {
    var name = ""
    var description = ""
    var servingSize = ""
    var calories: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?
  }

  let mode: Mode
  var prefill: Prefill?
  /// Called with the created/updated meal after a successful save.
  var onSaved: (CatalogMeal) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var categoryId = ""
  @State private var servingSize = ""
  @State private var description = ""
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""

  @State private var categories: [Category] = []
  @State private var categoriesLoading = false
  @State private var error: PresentableError?
  @State private var didPrefill = false

  @FocusState private var focus: Field?

  private enum Field: Hashable { case name, serving, description, calories, protein, carbs, fat }

  private var isEdit: Bool {
    if case .edit = mode { return true }
    return false
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var parsedCalories: Int? { NumberParsing.int(calories) }
  private var isValid: Bool {
    !trimmedName.isEmpty && !categoryId.isEmpty && (parsedCalories ?? -1) >= 0
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Meal name", text: $name)
            .focused($focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { focus = .serving }

          Picker("Category", selection: $categoryId) {
            Text(categoriesLoading ? "Loading…" : "Choose a category")
              .tag("")
            ForEach(categories) { category in
              Text(category.name).tag(category.id)
            }
          }
        }

        Section {
          TextField("e.g. 1 bowl (250 g) — optional", text: $servingSize)
            .focused($focus, equals: .serving)
          TextField("Description — optional", text: $description, axis: .vertical)
            .lineLimit(1...3)
            .focused($focus, equals: .description)
        } header: {
          Text("Serving")
        } footer: {
          // The add-to-log sheet parses this weight to offer grams-based
          // portions, so nudge every new meal to carry one.
          Text("Include the weight — like \"1 bowl (250 g)\" — so it can be logged by exact grams, not just servings.")
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
      .navigationTitle(isEdit ? "Edit meal" : "Add a meal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          AsyncButton(isEdit ? "Save" : "Add", style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
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
      .task {
        prefillIfNeeded()
        await loadCategories()
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private func macroField(
    _ label: LocalizedStringKey,
    text: Binding<String>,
    unit: String,
    field: Field,
    ink: Color
  ) -> some View {
    HStack {
      Text(label).foregroundStyle(Color.fuelInk)
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

  // MARK: - Data

  private func prefillIfNeeded() {
    guard !didPrefill else { return }
    switch mode {
    case let .edit(meal):
      name = meal.name
      categoryId = meal.category?.id ?? ""
      servingSize = meal.servingSize ?? ""
      description = meal.description ?? ""
      calories = intString(meal.calories)
      protein = intString(meal.protein)
      carbs = intString(meal.carbs)
      fat = intString(meal.fat)
    case .create:
      guard let prefill else { return }
      name = prefill.name
      description = prefill.description
      servingSize = prefill.servingSize
      calories = prefill.calories.map(String.init) ?? ""
      protein = prefill.protein.map(String.init) ?? ""
      carbs = prefill.carbs.map(String.init) ?? ""
      fat = prefill.fat.map(String.init) ?? ""
    }
    didPrefill = true
  }

  private func intString(_ value: Double) -> String {
    String(Int(value.rounded()))
  }

  private func loadCategories() async {
    guard categories.isEmpty else { return }
    categoriesLoading = true
    defer { categoriesLoading = false }
    categories = (try? await FuelAPI.categories()) ?? []
  }

  private func save() async throws {
    guard isValid, let kcal = parsedCalories else {
      throw APIError.server(message: String(localized: "Add a name, category and calories."), status: 400)
    }
    let trimmedServing = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

    let input = CatalogMealInput(
      name: trimmedName,
      description: trimmedDescription.isEmpty ? nil : trimmedDescription,
      categoryId: categoryId,
      servingSize: trimmedServing.isEmpty ? nil : trimmedServing,
      calories: kcal,
      protein: NumberParsing.int(protein) ?? 0,
      carbs: NumberParsing.int(carbs) ?? 0,
      fat: NumberParsing.int(fat) ?? 0
    )

    let saved: CatalogMeal
    switch mode {
    case .create:
      saved = try await FuelAPI.createMeal(input)
    case let .edit(meal):
      saved = try await FuelAPI.updateMeal(id: meal.id, input)
    }
    onSaved(saved)
    dismiss()
  }
}

#Preview {
  CatalogMealForm(mode: .create)
}
