import SwiftUI
import Charts

// The History tab. Unlike Today (a single-day rings hero), History is a
// 30-DAY view: twin trend charts (calories in green, protein in blue) with goal
// lines and a four-up stats strip, then a tappable LIST of days — each day row
// pushes a DayDetailView with the full meal-by-meal, meal-type and nutrition
// breakdown for that day.
struct HistoryView: View {
  @Environment(AppState.self) private var app
  @State private var model = HistoryViewModel()
  @State private var path: [String] = []

  private var direction: Direction {
    guard let p = app.profile else { return .maintain }
    return TargetMath.computeDirection(weightKg: p.weightKg, goalWeightKg: p.goalWeightKg)
  }

  var body: some View {
    NavigationStack(path: $path) {
      list
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.fuelBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarFade()
        .redacted(reason: !model.hasLoadedOnce && model.isRefreshing ? .placeholder : [])
        .refreshable { await model.refresh() }
        .navigationDestination(for: String.self) { key in
          DayDetailView(model: model, dayKey: key)
        }
    }
    .task { await model.initialLoad(targets: app.targets, direction: direction) }
    .onChange(of: app.targets) { model.updateContext(targets: app.targets, direction: direction) }
    .onChange(of: app.logRevision) {
      if model.hasLoadedOnce { Task { await model.refresh() } }
    }
  }

  private var list: some View {
    List {
      // MARK: 30-day hero
      Section {
        masthead.plainRow()
        MonthTrendCard(
          days: model.last30,
          calorieGoal: model.targets.calories,
          proteinGoal: model.targets.protein
        )
        .plainRow()
        statsStrip.plainRow()
      }

      if let error = model.error {
        Section {
          ErrorBanner(error: error, onRetry: { Task { await model.refresh() } }, onDismiss: { model.error = nil })
            .plainRow()
        }
      }

      // MARK: Tappable day list
      if model.isEmpty && model.hasLoadedOnce {
        Section { emptyRow.plainRow() }
      } else {
        Section {
          ForEach(model.days) { group in
            NavigationLink(value: group.key) {
              DayRow(group: group)
            }
            .listRowBackground(Color.fuelSurface)
          }
        } header: {
          Text("Daily log").fuelEyebrow().textCase(nil)
        }
      }
    }
  }

  // MARK: Masthead

  private var masthead: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Last 30 days").fuelEyebrow(color: .fuelVoltInk)
        Text("History")
          .font(.fuelMasthead)
          .foregroundStyle(Color.fuelInk)
      }
      Spacer()
      if model.streaks.logging >= 1 {
        PillBadge(title: "\(model.streaks.logging) day streak", systemImage: "flame.fill", tone: .gold)
      }
    }
  }

  private var statsStrip: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        StatTile(label: "Avg calories", value: model.avgCalories.formatted(), unit: "kcal/day",
                 systemImage: "flame.fill", tint: .fuelVoltInk)
        StatTile(label: "Avg protein", value: model.avgProtein.formatted(), unit: "g/day",
                 systemImage: "bolt.fill", tint: .fuelBlueInk)
      }
      HStack(spacing: 12) {
        StatTile(label: "Days logged", value: "\(model.daysLoggedCount)", unit: "of 30",
                 systemImage: "calendar", tint: .fuelVoltInk)
        StatTile(label: "Meals", value: "\(model.totalMeals)", unit: "logged",
                 systemImage: "fork.knife", tint: .fuelGoldInk)
      }
    }
  }

  private var emptyRow: some View {
    ContentUnavailableView {
      Label("No history yet", systemImage: "calendar")
    } description: {
      Text("Meals you log will appear here, grouped by day and meal.")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }
}

// MARK: - Day row (tappable → DayDetailView)

private struct DayRow: View {
  let group: HistoryViewModel.DayGroup

  private var mealCount: Int { group.meals.count }

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(FuelDateFormat.dayHeader(group.date))
          .font(.fuelHeading(.headline))
          .foregroundStyle(Color.fuelInk)
        Text("\(mealCount) \(mealCount == 1 ? "meal" : "meals")").fuelEyebrow()
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(group.totals.calories)")
            .font(.fuelMono(.headline, weight: 700))
            .foregroundStyle(Color.fuelInk)
            .contentTransition(.numericText())
          Text("kcal").fuelEyebrow()
        }
        MacroLetters(protein: group.totals.protein, carbs: group.totals.carbs,
                     fat: group.totals.fat, size: 11, spacing: 8)
      }
    }
    .padding(.vertical, 6)
  }
}

// MARK: - 30-day trend charts (calories + protein)

private struct MonthTrendCard: View {
  let days: [HistoryViewModel.HistoryDay]
  let calorieGoal: Int
  let proteinGoal: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      trend(title: "Calories", unit: "kcal", goal: calorieGoal, tint: .fuelOlive, warnOver: true) { $0.calories }
      Divider().overlay(Color.fuelInk.opacity(0.06))
      trend(title: "Protein", unit: "g", goal: proteinGoal, tint: .fuelBlue, warnOver: false) { $0.protein }
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .fuelCard()
  }

  private func trend(
    title: LocalizedStringKey,
    unit: String,
    goal: Int,
    tint: Color,
    warnOver: Bool,
    value: @escaping (HistoryViewModel.HistoryDay) -> Int
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.fuelHeading(.headline, weight: 600))
          .foregroundStyle(Color.fuelInk)
        Spacer()
        Text("goal \(goal) \(unit)")
          .font(.fuelMono(.caption2, weight: 500))
          .foregroundStyle(Color.fuelSubtle)
          .environment(\.layoutDirection, .leftToRight)
      }

      Chart {
        RuleMark(y: .value("Goal", goal))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
          .foregroundStyle(Color.fuelSubtle.opacity(0.5))

        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
          if day.logged {
            BarMark(
              x: .value("Day", index),
              y: .value(unit, value(day)),
              width: .fixed(6)
            )
            .cornerRadius(3)
            .foregroundStyle(barColor(for: value(day), goal: goal, tint: tint, warnOver: warnOver, isToday: day.isToday))
          }
        }
      }
      .frame(height: 104)
      .chartXScale(domain: -0.5...29.5)
      .chartYAxis(.hidden)
      .chartXAxis {
        AxisMarks(values: [0, 15, 29]) { value in
          AxisValueLabel {
            if let i = value.as(Int.self), days.indices.contains(i) {
              Text(days[i].isToday ? String(localized: "Today") : shortDate(days[i].date))
                .font(.fuelMono(.caption2))
                .foregroundStyle(Color.fuelSubtle)
            }
          }
        }
      }
    }
  }

  private func barColor(for value: Int, goal: Int, tint: Color, warnOver: Bool, isToday: Bool) -> Color {
    if warnOver && goal > 0 && value > goal { return isToday ? .fuelOver : Color.fuelOver.opacity(0.8) }
    return isToday ? tint : tint.opacity(0.55)
  }

  private func shortDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
  }
}

private extension View {
  func plainRow() -> some View {
    self
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}

#Preview {
  HistoryView()
    .environment(AppState())
}
