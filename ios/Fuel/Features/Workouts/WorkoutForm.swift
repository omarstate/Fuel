import SwiftUI

// Contribute an exercise to the shared catalog. Port of
// workouts/add-workout-dialog.tsx, built on the same Form + toolbar skeleton as
// CatalogMealForm so the two "add to the catalog" sheets behave identically.
//
// The one structural difference from the meals form: categories are MANY here
// (workout_category_map is many-to-many), so a Picker won't do — the web's
// multi-select ToggleGroup becomes a wrapping row of toggle chips.
struct WorkoutForm: View {
  /// Called with the created workout after a successful save, before dismissal —
  /// the Library uses it to invalidate its page cache.
  var onCreated: (Workout) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var selectedCategoryIds: Set<String> = []
  @State private var primaryMuscle = ""
  @State private var equipment = ""
  @State private var description = ""
  @State private var targetSets = ""
  @State private var targetReps = ""

  @State private var categories: [WorkoutCategory] = []
  @State private var categoriesLoading = false
  @State private var error: PresentableError?

  @FocusState private var focus: Field?

  private enum Field: Hashable {
    case name, primaryMuscle, equipment, description, targetSets, targetReps
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var isValid: Bool { !trimmedName.isEmpty && !selectedCategoryIds.isEmpty }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Workout name", text: $name)
            .focused($focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { focus = .primaryMuscle }
        }

        Section {
          categoryChips
        } header: {
          Text("Types")
        } footer: {
          Text(categoryFooter)
        }

        Section("Details") {
          TextField("Primary muscle — e.g. Chest", text: $primaryMuscle)
            .focused($focus, equals: .primaryMuscle)
            .submitLabel(.next)
            .onSubmit { focus = .equipment }
          TextField("Equipment — e.g. Barbell", text: $equipment)
            .focused($focus, equals: .equipment)
          TextField("Description — optional", text: $description, axis: .vertical)
            .lineLimit(1...3)
            .focused($focus, equals: .description)
        }

        Section {
          HStack {
            Text("Target sets").foregroundStyle(Color.fuelInk)
            Spacer()
            TextField("4", text: $targetSets)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .font(.fuelMono(.body))
              .focused($focus, equals: .targetSets)
              .frame(maxWidth: 90)
          }
          HStack {
            Text("Target reps").foregroundStyle(Color.fuelInk)
            Spacer()
            // Free-form on purpose: "8-12", "AMRAP", "to failure" are all valid
            // and the backend stores the string verbatim.
            TextField("8-12", text: $targetReps)
              .multilineTextAlignment(.trailing)
              .font(.fuelMono(.body))
              .focused($focus, equals: .targetReps)
              .frame(maxWidth: 120)
          }
        } header: {
          Text("Target volume")
        } footer: {
          Text("Both optional — they're a suggestion shown on the card, not a rule.")
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
      .navigationTitle("Add a workout")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          AsyncButton("Add", style: .glassProminent, tint: .fuelWorkout, successHaptic: true) {
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
      .task { await loadCategories() }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  // MARK: - Categories

  // Annotated so the ternary resolves to a localizable key, not a bare String.
  private var categoryFooter: LocalizedStringKey {
    selectedCategoryIds.isEmpty
      ? "Pick at least one type."
      : "A workout can belong to several types — pick every one that fits."
  }

  @ViewBuilder
  private var categoryChips: some View {
    if categoriesLoading && categories.isEmpty {
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text("Loading types…")
          .font(.fuelBody(.subheadline))
          .foregroundStyle(Color.fuelSubtle)
      }
    } else if categories.isEmpty {
      Text("Couldn't load workout types.")
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
    } else {
      FlowLayout(spacing: 8, lineSpacing: 8) {
        ForEach(categories) { category in
          categoryChip(category)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func categoryChip(_ category: WorkoutCategory) -> some View {
    let selected = selectedCategoryIds.contains(category.id)
    return Button {
      withAnimation(.snappy) {
        if selected {
          selectedCategoryIds.remove(category.id)
        } else {
          selectedCategoryIds.insert(category.id)
        }
      }
    } label: {
      HStack(spacing: 5) {
        if selected {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
        }
        Text(category.name)
          .font(.fuelMono(.caption, weight: 600))
          .textCase(.uppercase)
          .tracking(0.6)
      }
      .foregroundStyle(selected ? Color.fuelWorkoutInk : Color.fuelSubtle)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        selected ? Color.fuelWorkout.opacity(0.16) : Color.clear,
        in: Capsule()
      )
      .overlay(
        Capsule().strokeBorder(
          selected ? Color.fuelWorkoutInk.opacity(0.35) : Color.fuelInk.opacity(0.12),
          lineWidth: 1
        )
      )
      .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(category.name)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
  }

  private func loadCategories() async {
    guard categories.isEmpty else { return }
    categoriesLoading = true
    defer { categoriesLoading = false }
    categories = (try? await FuelAPI.workoutCategories()) ?? []
  }

  // MARK: - Save

  private func save() async throws {
    guard isValid else {
      throw APIError.server(message: String(localized: "Add a name and at least one type."), status: 400)
    }
    focus = nil

    // Every optional on createWorkoutSchema is `.optional()`, never nullable, so
    // an empty field must be nil (omitted) rather than an empty string.
    let input = WorkoutInput(
      name: trimmedName,
      description: cleaned(description),
      // Ordered by the catalog's own sortOrder rather than tap order, so the
      // chips on the resulting card come back in a stable sequence.
      categoryIds: categories.map(\.id).filter(selectedCategoryIds.contains),
      primaryMuscle: cleaned(primaryMuscle),
      equipment: cleaned(equipment),
      targetSets: NumberParsing.int(targetSets),
      targetReps: cleaned(targetReps)
    )

    let created = try await FuelAPI.createWorkout(input)
    onCreated(created)
    dismiss()
  }

  private func cleaned(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

#Preview {
  WorkoutForm()
}
