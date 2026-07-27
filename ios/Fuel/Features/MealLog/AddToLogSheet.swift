import SwiftUI

// Logs a catalog meal to the personal log. Presents a meal-type section picker
// (the time-of-day suggestion first, tagged "Suggested" — never hardcoded), a
// serving multiplier stepper (0.5×–3×) that scales the macros live, and a
// primary Log button. Writes straight to MealLogRepository with the catalog
// meal id attached, then dismisses. Shared by meal detail and Library rows.
struct AddToLogSheet: View {
  let meal: CatalogMeal
  /// Fired after a successful log, before dismissal (e.g. to nudge a refresh).
  var onLogged: () -> Void = {}

  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var app

  @State private var mealType: MealType = MealTypeSuggestion.suggested()
  @State private var factor: Double = 1
  @State private var error: PresentableError?

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

  // Serving text stored on the log entry, annotated with the multiplier when ≠1×.
  private var loggedServingSize: String? {
    let base = meal.servingSize?.trimmingCharacters(in: .whitespaces)
    let isWhole = factor == 1
    if let base, !base.isEmpty {
      return isWhole ? base : "\(PortionScaling.factorLabel(factor))× \(base)"
    }
    return isWhole ? nil : "\(PortionScaling.factorLabel(factor)) servings"
  }

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

        Section("Servings") {
          portionStepper
          macroPreview
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
          factor = max(minFactor, factor - 0.5)
        }
        Text("\(PortionScaling.factorLabel(factor))×")
          .font(.fuelMono(.body, weight: 600))
          .foregroundStyle(Color.fuelInk)
          .frame(minWidth: 44)
          .contentTransition(.numericText())
        stepButton(systemName: "plus", disabled: factor >= maxFactor) {
          factor = min(maxFactor, factor + 0.5)
        }
      }
    }
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
