import SwiftUI

// The flagship screen: one glance answers "how am I doing today?" — a Google
// Sans Flex date masthead + streak, a calorie ring with pace line and macro
// bars (numbers in JetBrains Mono), a compact
// week chart, and the grouped meal log. A floating glass toolbar logs meals.
struct TodayView: View {
  @Environment(AppState.self) private var app
  @Environment(\.scenePhase) private var scenePhase
  @State private var model = TodayViewModel()
  @State private var showManualAdd = false
  @State private var addToType: MealType?
  @State private var showVoice = false
  @State private var showEstimate = false
  @State private var showLookup = false
  @State private var showPhoto = false
  @State private var showBarcode = false
  @State private var deleteTick = 0
  @State private var pendingDelete: LoggedMeal?

  private var goalReached: Bool {
    model.targets.calories > 0 && model.consumed >= model.targets.calories
  }

  private var direction: Direction {
    guard let p = app.profile else { return .maintain }
    return TargetMath.computeDirection(weightKg: p.weightKg, goalWeightKg: p.goalWeightKg)
  }

  var body: some View {
    NavigationStack {
      list
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.fuelBackground)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .redacted(reason: showSkeleton ? .placeholder : [])
        .toolbar(.hidden, for: .navigationBar)
        .statusBarFade()
        .sensoryFeedback(trigger: goalReached) { old, new in new && !old ? .success : nil }
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteTick)
        .refreshable { await model.refresh() }
    }
    .task {
      await model.initialLoad(targets: app.targets, direction: direction)
      // Roll over to the fresh (empty) day at local midnight while open.
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(DayBounds.intervalUntilNextMidnight()))
        if Task.isCancelled { break }
        await model.refresh()
      }
    }
    .onChange(of: app.targets) { model.updateContext(targets: app.targets, direction: direction) }
    .onChange(of: app.logRevision) {
      if model.hasLoadedOnce { Task { await model.refresh() } }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active, model.hasLoadedOnce { Task { await model.refresh() } }
    }
    // The plus now lives in the global bottom bar (MainTabView); it hands the
    // picked flow over here because this screen owns the log + its view model.
    .onChange(of: app.pendingLogRequest) { _, requested in
      guard let requested else { return }
      switch requested {
      case .manual: showManualAdd = true
      case .action(let kind): handleAction(kind)
      }
      app.pendingLogRequest = nil
    }
    .sheet(isPresented: $showManualAdd) {
      ManualAddSheet { new in
        try await model.log(new)
        app.bumpLogRevision()
      }
    }
    .sheet(item: $addToType) { type in
      ManualAddSheet(onSave: { new in
        try await model.log(new)
        app.bumpLogRevision()
      }, preselectedType: type)
    }
    .sheet(isPresented: $showVoice) { VoiceLogFlow() }
    .sheet(isPresented: $showEstimate) { AIEstimateFlow() }
    .sheet(isPresented: $showLookup) { AILookupSheet() }
    .sheet(isPresented: $showPhoto) { PhotoLabelFlow() }
    .fullScreenCover(isPresented: $showBarcode) { BarcodeScanView() }
    .confirmationDialog(
      "Remove this meal?",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible,
      presenting: pendingDelete
    ) { meal in
      Button("Remove \(meal.name)", role: .destructive) { delete(meal) }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: { meal in
      Text("\(meal.name) (\(meal.calories) kcal) will be removed from today's log.")
    }
  }

  // The bottom bar's voice + AI + scan actions. All real flows.
  private func handleAction(_ kind: LogAction) {
    switch kind {
    case .voice: showVoice = true
    case .estimate: showEstimate = true
    case .lookup: showLookup = true
    case .photo: showPhoto = true
    case .barcode: showBarcode = true
    }
  }

  private var showSkeleton: Bool { !model.hasLoadedOnce && model.isRefreshing }

  // MARK: - List

  private var list: some View {
    List {
      Section {
        HeroCard(model: model)
          .plainRow()
      }

      if let error = model.error {
        Section {
          ErrorBanner(error: error, onRetry: { Task { await model.refresh() } }, onDismiss: { model.error = nil })
            .plainRow()
        }
      }

      ForEach(model.sections, id: \.type) { section in
        Section {
          if section.meals.isEmpty {
            emptyRow(for: section.type)
              .listRowBackground(Color.fuelSurface)
          } else {
            ForEach(section.meals) { meal in
              // Trash button + long-press ask for confirmation; the swipe's
              // labeled destructive button stays immediate (iOS convention).
              MealRow(meal: meal, onDelete: { pendingDelete = meal })
                .listRowBackground(Color.fuelSurface)
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) {
                    delete(meal)
                  } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
                .contextMenu {
                  Button(role: .destructive) {
                    pendingDelete = meal
                  } label: {
                    Label("Remove from log", systemImage: "trash")
                  }
                }
            }
          }
        } header: {
          sectionHeader(for: section)
        }
      }
    }
  }

  private func delete(_ meal: LoggedMeal) {
    Task {
      await model.delete(meal)
      deleteTick += 1
      app.bumpLogRevision()
    }
  }

  // "BREAKFAST · 380 KCAL" — the meal-type eyebrow with a mono kcal subtotal.
  private func sectionHeader(for section: (type: MealType, meals: [LoggedMeal])) -> some View {
    Group {
      if section.meals.isEmpty {
        Text(section.type.label)
      } else {
        Text("\(section.type.label) · \(section.meals.totals.calories) kcal")
      }
    }
    .fuelEyebrow()
    .textCase(nil)
    .contentTransition(.numericText())
  }

  // Empty section: a quiet "Nothing logged yet" line with an inline "+ Add" that
  // opens the log flow preselected to this meal type.
  private func emptyRow(for type: MealType) -> some View {
    HStack {
      Text("Nothing logged yet")
        .font(.fuelBody(.footnote))
        .foregroundStyle(Color.fuelSubtle)
      Spacer()
      Button {
        addToType = type
      } label: {
        Label("Add", systemImage: "plus")
          .font(.fuelBody(.footnote, weight: 600))
          .foregroundStyle(Color.fuelVoltInk)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 2)
  }
}

// MARK: - Hero

private struct HeroCard: View {
  let model: TodayViewModel

  private var pace: PaceReading { model.pace }

  // Localized, capitalized pace phrase. Built as a LocalizedStringKey so it
  // resolves per-locale (the Core/Logic PaceReading stays SwiftUI-free).
  private var paceLabel: LocalizedStringKey {
    switch pace.labelKey {
    case .overGoal: return "Over goal"
    case .aheadOfPace: return "Ahead of pace"
    case .roomToSpare: return "Room to spare"
    case .onPace: return "On pace"
    }
  }

  // "1,140 left · on pace" — remaining first (or the amount over), then the
  // localized pace phrase. Text interpolation preserves per-piece localization
  // and Arabic-Indic numerals.
  private var paceText: Text {
    let tail = Text(paceLabel)
    if pace.status == .over {
      return Text("\(abs(pace.remaining)) kcal over · \(tail)")
    }
    return Text("\(model.remaining) left · \(tail)")
  }

  private var paceColor: Color {
    switch pace.status {
    case .over: return .fuelOver
    case .behind: return .fuelSubtle
    default: return .fuelVoltInk
    }
  }

  var body: some View {
    // Centered masthead + dual activity rings, bare on the charcoal canvas —
    // mirroring the web Today hero. No card: the rings ARE the hero.
    VStack(spacing: 18) {
      VStack(spacing: 7) {
        Text(FuelDateFormat.eyebrow(Date())).fuelEyebrow(color: .fuelVoltInk)
        Text("Today")
          .font(.fuelMasthead)
          .foregroundStyle(Color.fuelInk)
        if model.streaks.logging >= 1 {
          PillBadge(title: "\(model.streaks.logging) day streak", systemImage: "flame.fill", tone: .gold)
        }
      }

      ActivityRings(
        consumed: model.consumed,
        calorieTarget: model.targets.calories,
        protein: model.totals.protein,
        proteinTarget: model.targets.protein,
        carbs: model.totals.carbs,
        carbTarget: model.targets.carbs,
        fat: model.totals.fat,
        fatTarget: model.targets.fat
      )
      .padding(.top, 2)

      paceText
        .font(.fuelMono(.footnote, weight: 600))
        .foregroundStyle(paceColor)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 4)
  }
}

// Shared modifier: a clear, separator-less, edge-to-edge list row for cards.
private extension View {
  func plainRow() -> some View {
    self
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}

#Preview {
  TodayView()
    .environment(AppState())
}
