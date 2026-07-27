import SwiftUI

// AI estimate flow: describe what you ate in free text, get one editable review
// row per item, then log them all to today (and best-effort into the shared
// catalog). Two steps in one sheet. `ok == false` rows are soft failures —
// flagged, zeroed, and includable once the user fills in a name + calories.
struct AIEstimateFlow: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  @State private var step: Step = .input
  @State private var place = ""
  @State private var itemsText = ""
  @State private var mealType: MealType = MealTypeSuggestion.suggested()
  @State private var estimating = false
  @State private var rows: [EstimateRow] = []
  @State private var error: PresentableError?
  @FocusState private var keyboardActive: Bool

  private let repo = MealLogRepository()

  private enum Step { case input, review }

  private var parsedItems: [String] {
    itemsText
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private var usableCount: Int { rows.filter(\.isUsable).count }

  var body: some View {
    NavigationStack {
      Group {
        if estimating {
          estimatingState
        } else {
          switch step {
          case .input: inputForm
          case .review: reviewForm
          }
        }
      }
      .background(Color.fuelBackground)
      .navigationTitle(step == .input ? "Estimate with AI" : "Review estimates")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(estimating)
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if step == .input {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { dismiss() }
          .disabled(estimating)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          runEstimate()
        } label: {
          Label("Estimate", systemImage: "sparkles")
            .font(.fuelBody(.subheadline, weight: 600))
        }
        .disabled(parsedItems.isEmpty || estimating)
      }
    } else {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          step = .input
        } label: {
          Label("Back", systemImage: "chevron.backward")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        AsyncButton(saveLabel, style: .glassProminent, tint: .fuelCitrus, successHaptic: true) {
          try await saveAll()
        } onError: { err in
          error = PresentableError(err)
        }
        .disabled(usableCount == 0)
      }
    }
  }

  private var saveLabel: LocalizedStringKey {
    usableCount <= 1 ? "Log meal" : "Log \(usableCount) meals"
  }

  // MARK: - Input step

  private var inputForm: some View {
    Form {
      Section {
        TextField("Where from? (optional) e.g. McDonald's Egypt", text: $place)
          .focused($keyboardActive)
      } header: {
        Text("Place")
      } footer: {
        Text("Egyptian menus and portions are checked first.")
      }

      Section {
        TextField("e.g. 2 eggs, foul sandwich, mango juice", text: $itemsText, axis: .vertical)
          .lineLimit(2...5)
          .focused($keyboardActive)
      } header: {
        Text("What did you eat?")
      } footer: {
        Text(parsedItems.isEmpty
          ? "Separate each item with a comma."
          : "\(parsedItems.count) items detected.")
      }

      Section("Meal") {
        Picker("Section", selection: $mealType) {
          ForEach(MealType.allCases) { type in
            Text(type.label).tag(type)
          }
        }
        .pickerStyle(.segmented)
      }

      if let error {
        Section {
          ErrorBanner(error: error, onDismiss: { self.error = nil })
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { keyboardActive = false }
      }
    }
  }

  // MARK: - Estimating state

  private var estimatingState: some View {
    AIProgressView(hints: estimateHints, title: "Estimating your meal…")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var estimateHints: [LocalizedStringKey] {
    var hints: [LocalizedStringKey] = ["Checking Egyptian menus first…"]
    hints += parsedItems.prefix(6).map { LocalizedStringKey("Looking up \($0)…") }
    hints.append("Crunching the macros…")
    return hints
  }

  // MARK: - Review step

  private var reviewForm: some View {
    Form {
      Section {
        Text("Logging to \(mealType.label) · check the numbers and edit anything that looks off.")
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
          .listRowBackground(Color.clear)
      }

      ForEach($rows) { $row in
        reviewSection($row)
      }

      if let error {
        Section {
          ErrorBanner(error: error, onDismiss: { self.error = nil })
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { keyboardActive = false }
      }
    }
  }

  @ViewBuilder
  private func reviewSection(_ row: Binding<EstimateRow>) -> some View {
    Section {
      TextField("Meal name", text: row.name)
        .font(.fuelBody(.body, weight: 500))
        .foregroundStyle(Color.fuelInk)
        .focused($keyboardActive)
      TextField("Serving size (optional)", text: row.servingSize)
        .font(.fuelBody(.subheadline))
        .focused($keyboardActive)
      macroField("Calories", text: row.calories, unit: "kcal", ink: MacroPalette.caloriesInk)
      macroField("Protein", text: row.protein, unit: "g", ink: MacroPalette.proteinInk)
      macroField("Carbs", text: row.carbs, unit: "g", ink: MacroPalette.carbsInk)
      macroField("Fat", text: row.fat, unit: "g", ink: MacroPalette.fatInk)
    } header: {
      HStack(spacing: 6) {
        sourceBadge(row.wrappedValue)
        if let confidence = row.wrappedValue.confidence {
          PillBadge(title: "\(confidence.label)", tone: .neutral)
        }
        Spacer()
        Button(role: .destructive) {
          withAnimation(.snappy) { rows.removeAll { $0.id == row.wrappedValue.id } }
        } label: {
          Image(systemName: "trash")
            .font(.caption.weight(.semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.fuelDestructive)
        .textCase(nil)
        .accessibilityLabel("Remove item")
      }
    } footer: {
      footer(for: row.wrappedValue)
    }
  }

  @ViewBuilder
  private func footer(for row: EstimateRow) -> some View {
    if !row.ok {
      Text("Couldn't estimate — fill in a name and calories by hand to include it.")
        .foregroundStyle(Color.fuelCitrusInk)
    } else if !row.note.trimmingCharacters(in: .whitespaces).isEmpty {
      Text(row.note)
        .foregroundStyle(Color.fuelSubtle)
    }
  }

  @ViewBuilder
  private func sourceBadge(_ row: EstimateRow) -> some View {
    if let source = row.source {
      PillBadge(title: "\(source.label)", tone: source == .egypt ? .citrus : .neutral)
    } else {
      Text("Estimate").fuelEyebrow()
    }
  }

  private func macroField(_ label: LocalizedStringKey, text: Binding<String>, unit: String, ink: Color) -> some View {
    HStack {
      Text(label).foregroundStyle(Color.fuelInk)
      Spacer()
      TextField("0", text: text)
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

  // MARK: - Actions

  private func runEstimate() {
    let items = parsedItems
    guard !items.isEmpty, !estimating else { return }
    keyboardActive = false
    estimating = true
    error = nil
    let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
    Task {
      defer { estimating = false }
      do {
        let results = try await FuelAPI.estimateMeals(
          place: trimmedPlace.isEmpty ? nil : trimmedPlace,
          items: items
        )
        rows = results.map(EstimateRow.init(from:))
        step = .review
      } catch {
        self.error = PresentableError(error)
      }
    }
  }

  private func saveAll() async throws {
    let usable = rows.filter(\.isUsable)
    guard !usable.isEmpty else {
      throw APIError.server(message: String(localized: "Add a name and calories to at least one item."), status: 400)
    }
    let userID = try await repo.userID()
    let now = Date()

    // Log each usable row to the personal log. Independent inserts so one
    // failure doesn't drop the rest.
    var saved = 0
    for row in usable {
      guard let meal = row.loggedMeal(userId: userID, mealType: mealType, loggedAt: now) else { continue }
      do {
        try await repo.insert(meal)
        saved += 1
      } catch {
        // keep going; surfaced below if nothing landed
      }
    }
    guard saved > 0 else {
      throw APIError.server(message: String(localized: "Couldn't log those meals. Try again."), status: 500)
    }

    // Best-effort: contribute the reviewed rows to the shared AI catalog. A
    // failure here must never block logging the day.
    let catalogInputs = rows.dedupedCatalogInputs()
    if !catalogInputs.isEmpty {
      _ = try? await FuelAPI.saveAiCatalog(meals: catalogInputs)
    }

    app.bumpLogRevision()
    dismiss()
  }
}

#Preview {
  AIEstimateFlow()
    .environment(AppState())
}
