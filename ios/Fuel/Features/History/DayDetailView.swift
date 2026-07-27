import SwiftUI

// A single day's log, pushed from the History list. Opens with a summary card
// (day total vs target + macro bars), then the meals split into Breakfast /
// Lunch / Dinner / Snack sections with per-section subtotals. Reads the day
// live from the shared HistoryViewModel by key, so an in-place delete updates
// here and pops back when the day empties out.
struct DayDetailView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let model: HistoryViewModel
  let dayKey: String
  @State private var pendingDelete: LoggedMeal?
  @State private var deleteTick = 0

  private var group: HistoryViewModel.DayGroup? { model.days.first { $0.key == dayKey } }
  private var targets: Targets { model.targets }
  private var title: String {
    group.map { FuelDateFormat.dayHeader($0.date) } ?? String(localized: "Day")
  }

  var body: some View {
    List {
      if let group {
        Section {
          DaySummaryCard(group: group, targets: targets).plainDetailRow()
        }
        ForEach(group.byType, id: \.type) { bucket in
          Section {
            ForEach(bucket.meals) { meal in
              MealRow(meal: meal, onDelete: { pendingDelete = meal })
                .listRowBackground(Color.fuelSurface)
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) { delete(meal) } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
            }
          } header: {
            MealTypeHeader(type: bucket.type, kcal: bucket.meals.totals.calories, count: bucket.meals.count)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.fuelBackground)
    .scrollEdgeEffectStyle(.soft, for: .top)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
    .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
    .confirmationDialog(
      "Remove this meal?",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible,
      presenting: pendingDelete
    ) { meal in
      Button("Remove \(meal.name)", role: .destructive) { delete(meal) }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: { meal in
      Text("\(meal.name) (\(meal.calories) kcal) will be removed from your log.")
    }
    // Pop back once the day has no meals left.
    .onChange(of: model.days.contains { $0.key == dayKey }) { _, exists in
      if !exists { dismiss() }
    }
  }

  private func delete(_ meal: LoggedMeal) {
    Task {
      await model.delete(meal)
      deleteTick += 1
      app.bumpLogRevision()
    }
  }
}

// MARK: - Day summary (total vs target + macro bars)

private struct DaySummaryCard: View {
  let group: HistoryViewModel.DayGroup
  let targets: Targets

  private var totals: LoggedMeal.Totals { group.totals }
  private var over: Bool { totals.calories > targets.calories }
  private var remaining: Int { max(targets.calories - totals.calories, 0) }
  private var mealCount: Int { group.meals.count }

  var body: some View {
    VStack(spacing: 18) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("\(totals.calories)")
          .font(.fuelHeading(46, weight: 700, relativeTo: .largeTitle))
          .foregroundStyle(Color.fuelOlive)
          .contentTransition(.numericText())
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        VStack(alignment: .leading, spacing: 2) {
          Text("kcal").fuelEyebrow()
          Text("of \(targets.calories)")
            .font(.fuelMono(.footnote, weight: 500))
            .foregroundStyle(Color.fuelSubtle)
        }
        Spacer(minLength: 0)
        Text(over ? "\(totals.calories - targets.calories) over" : "\(remaining) left")
          .font(.fuelMono(.footnote, weight: 600))
          .foregroundStyle(over ? Color.fuelOver : Color.fuelVoltInk)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            (over ? Color.fuelOver.opacity(0.12) : Color.fuelOlive.opacity(0.15)),
            in: Capsule()
          )
      }

      Divider().overlay(Color.fuelInk.opacity(0.06))

      VStack(spacing: 14) {
        MacroBar(label: "Protein", value: totals.protein, goal: targets.protein,
                 fill: MacroPalette.proteinFill, ink: MacroPalette.proteinInk)
        MacroBar(label: "Carbs", value: totals.carbs, goal: targets.carbs,
                 fill: MacroPalette.carbsFill, ink: MacroPalette.carbsInk)
        MacroBar(label: "Fat", value: totals.fat, goal: targets.fat,
                 fill: MacroPalette.fatFill, ink: MacroPalette.fatInk)
      }

      HStack {
        Text("\(mealCount) \(mealCount == 1 ? "meal" : "meals") logged").fuelEyebrow()
        Spacer()
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity)
    .fuelCard()
  }
}

// MARK: - Meal-type section header

struct MealTypeHeader: View {
  let type: MealType
  let kcal: Int
  var count: Int?

  private var icon: String {
    switch type {
    case .breakfast: return "sunrise.fill"
    case .lunch: return "sun.max.fill"
    case .dinner: return "moon.stars.fill"
    case .snack: return "leaf.fill"
    }
  }

  private var tint: Color {
    switch type {
    case .breakfast: return .fuelGoldInk
    case .lunch: return .fuelVoltInk
    case .dinner: return .fuelBlueInk
    case .snack: return .fuelOver
    }
  }

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: icon)
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
      Text(type.label)
        .font(.fuelMono(11, weight: 700, relativeTo: .caption2))
        .textCase(.uppercase)
        .tracking(11 * 0.14)
        .foregroundStyle(tint)
      Spacer()
      if let count {
        Text("\(count) \(count == 1 ? "item" : "items")")
          .fuelEyebrow()
          .textCase(nil)
      }
      Text("\(kcal) kcal")
        .font(.fuelMono(.caption, weight: 600))
        .foregroundStyle(Color.fuelSubtle)
        .textCase(nil)
    }
    .padding(.vertical, 2)
  }
}

private extension View {
  func plainDetailRow() -> some View {
    self
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}
