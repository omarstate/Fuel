import SwiftUI

// The History tab. Unlike Today (a single-day rings hero), History is a
// 30-DAY view built around READABLE NUMBERS, not charts: a "This week" rollup
// (avg kcal/day, days on target, the direction-aware verdict from
// WeekAggregation), a four-up stats strip, then a tappable LIST of days — each
// row carries a goal-outcome dot and pushes a DayDetailView with the full
// meal-by-meal breakdown. The twin 30-day trend charts that used to sit here
// were removed deliberately (Omar: extracting data from them was useless) —
// don't bring bar charts back; extend the numeric summaries instead.
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
        if model.weekSummary.hasData {
          WeekSummaryCard(summary: model.weekSummary).plainRow()
        }
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
              DayRow(group: group, calorieGoal: model.targets.calories)
            }
            .listRowBackground(Color.fuelSurface)
          }
        } header: {
          HStack {
            Text("Daily log").fuelEyebrow().textCase(nil)
            Spacer()
            outcomeLegend
          }
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

  /// Decodes the day-row dots: on target (filled green), over (filled red),
  /// under (hollow). VoiceOver reads each row's outcome instead.
  private var outcomeLegend: some View {
    HStack(spacing: 10) {
      legendItem(.onTarget, label: "on target")
      legendItem(.over, label: "over")
      legendItem(.under, label: "under")
    }
    .accessibilityHidden(true)
  }

  private func legendItem(_ outcome: WeekAggregation.Outcome, label: LocalizedStringKey) -> some View {
    HStack(spacing: 4) {
      OutcomeDot(outcome: outcome, size: 6)
      Text(label).fuelEyebrow(size: 10).textCase(nil)
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
  let calorieGoal: Int

  private var mealCount: Int { group.meals.count }

  /// Same ±10% band the streaks and week summary use, so every surface agrees
  /// on what "on target" means.
  private var outcome: WeekAggregation.Outcome {
    WeekAggregation.outcome(calories: group.totals.calories, goal: calorieGoal)
  }

  private var outcomeText: LocalizedStringKey {
    switch outcome {
    case .onTarget: return "On target"
    case .over: return "Over goal"
    case .under: return "Under goal"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      OutcomeDot(outcome: outcome, size: 8)
        .accessibilityElement()
        .accessibilityLabel(outcomeText)
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

// MARK: - This-week rollup (replaces the old trend charts)

// The numbers a coach would actually pull out of a chart, precomputed:
// average intake, adherence count, and the direction-aware net verdict
// ("On track to lose ≈0.3 kg"). All from WeekAggregation — no new math.
private struct WeekSummaryCard: View {
  let summary: WeekSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("This week").fuelEyebrow(color: .fuelVoltInk)
        Spacer()
        Text("\(summary.daysOnTarget) of \(summary.trackedCount) days on target")
          .font(.fuelMono(.caption, weight: 600))
          .foregroundStyle(Color.fuelSubtle)
      }

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(summary.dailyAverage)")
          .font(.fuelMono(28, weight: 700, relativeTo: .title2))
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
        Text("kcal/day average").fuelEyebrow()
      }

      Text(summary.text)
        .font(.fuelBody(.footnote, weight: 500))
        .foregroundStyle(summary.onTrack ? Color.fuelVoltInk : Color.fuelOver)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
  }
}

// MARK: - Goal-outcome dot (day rows + legend)

private struct OutcomeDot: View {
  let outcome: WeekAggregation.Outcome
  let size: CGFloat

  var body: some View {
    switch outcome {
    case .onTarget:
      Circle().fill(Color.fuelVolt).frame(width: size, height: size)
    case .over:
      Circle().fill(Color.fuelOver).frame(width: size, height: size)
    case .under:
      Circle()
        .strokeBorder(Color.fuelSubtle.opacity(0.6), lineWidth: 1.5)
        .frame(width: size, height: size)
    }
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
