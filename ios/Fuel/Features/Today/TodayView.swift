import SwiftUI

// The flagship screen, in the light editorial layout: a greeting header with the
// logging streak, a "LEFT TO EAT" hero whose stacked bar shows which sections the
// day's calories came from (plus what Health says was burned), three macro tiles,
// one-tap rows for the meals this user repeats, and a collapsible card per meal
// section. Everything is opaque cream cards on the warm canvas; the floating glass
// lives in the bottom bar (MainTabView), which hands its log flows over to here.
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
  /// Which section cards are open. Sections start collapsed — the card's kcal
  /// subtotal is the answer most glances need.
  @State private var expanded: Set<MealType> = []

  private var goalReached: Bool {
    model.targets.calories > 0 && model.consumed >= model.targets.calories
  }

  private var direction: Direction {
    guard let p = app.profile else { return .maintain }
    return TargetMath.computeDirection(weightKg: p.weightKg, goalWeightKg: p.goalWeightKg)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          header

          if let error = model.error {
            ErrorBanner(error: error, onRetry: { Task { await model.refresh() } }, onDismiss: { model.error = nil })
          }

          HeroCard(model: model)
          macroTiles
          sectionCards
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        // The stock tab bar insets the scroll view itself; this is just breath.
        .padding(.bottom, 24)
      }
      .background(Color.fuelBackground.ignoresSafeArea())
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
    // The per-section "+ Add" opens the full-screen panel: every log method plus
    // the catalog, all scoped to that section. The bottom bar's "Add manually"
    // still goes straight to ManualAddSheet above.
    .fullScreenCover(item: $addToType) { type in
      AddMealPanel(mealType: type)
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

  // MARK: - Header

  // Date eyebrow + streak pill, then the greeting. Bare on the canvas — the
  // cards below start the content, so the header reads as a masthead.
  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        Text(FuelDateFormat.eyebrow(Date())).fuelEyebrow()
        Spacer(minLength: 8)
        if model.streaks.logging >= 1 { streakPill }
        // The door to the workouts side — swaps the whole tab bar.
        SideSwitcher()
      }
      greeting
        .font(.fuelMasthead)
        .foregroundStyle(Color.fuelInk)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.bottom, 2)
  }

  // A plain gold dot, not a flame: the streak is a quiet fact up here, not a
  // trophy competing with the hero number below.
  private var streakPill: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(Color.fuelGold)
        .frame(width: 7, height: 7)
      Text("\(model.streaks.logging) day streak")
        .font(.fuelBody(.footnote, weight: 600))
        .foregroundStyle(Color.fuelGoldInk)
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(Color.fuelGold.opacity(0.18), in: Capsule())
    .accessibilityElement(children: .combine)
  }

  /// Time-of-day greeting, personalised when auth metadata carries a name.
  private var greeting: Text {
    if let name = firstName {
      switch daypart {
      case .morning: return Text("Morning, \(name)")
      case .afternoon: return Text("Afternoon, \(name)")
      case .evening: return Text("Evening, \(name)")
      }
    }
    switch daypart {
    case .morning: return Text("Morning")
    case .afternoon: return Text("Afternoon")
    case .evening: return Text("Evening")
    }
  }

  private enum Daypart { case morning, afternoon, evening }

  private var daypart: Daypart {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 { return .morning }
    if hour < 16 { return .afternoon }
    return .evening
  }

  /// First whitespace-separated token of the display name — "Omar" from
  /// "Omar State". Nil when the account has no name set.
  private var firstName: String? {
    guard let full = app.displayName else { return nil }
    guard let first = full.split(whereSeparator: \.isWhitespace).first else { return nil }
    return String(first)
  }

  // MARK: - Macro tiles

  private var macroTiles: some View {
    HStack(spacing: 12) {
      MacroTile(name: "Protein", value: model.totals.protein, target: model.targets.protein, fill: MacroPalette.proteinFill)
      MacroTile(name: "Carbs", value: model.totals.carbs, target: model.targets.carbs, fill: MacroPalette.carbsFill)
      MacroTile(name: "Fat", value: model.totals.fat, target: model.targets.fat, fill: MacroPalette.fatFill)
    }
  }

  // MARK: - Sections

  private var sectionCards: some View {
    ForEach(model.sections, id: \.type) { section in
      MealSectionCard(
        type: section.type,
        meals: section.meals,
        isExpanded: expanded.contains(section.type),
        onToggle: {
          withAnimation(.snappy) {
            if expanded.contains(section.type) {
              expanded.remove(section.type)
            } else {
              expanded.insert(section.type)
            }
          }
        },
        onAdd: { addToType = section.type },
        onDelete: { pendingDelete = $0 }
      )
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

// MARK: - Hero

// "LEFT TO EAT": the one number the screen exists to answer, what's been eaten
// and burned beside it, a bar segmented by which meal the calories came from,
// and a plain-language pace line.
private struct HeroCard: View {
  let model: TodayViewModel

  /// Only the sections with food, in canonical order — they become the bar's
  /// segments and share the section cards' colors.
  private var segments: [(type: MealType, kcal: Int)] {
    model.sections.compactMap { section in
      let kcal = section.meals.totals.calories
      return kcal > 0 ? (section.type, kcal) : nil
    }
  }

  /// Bar scale. Once consumed passes the goal the bar rescales to consumed, so
  /// going over compresses the segments instead of overflowing the track.
  private var scale: CGFloat {
    CGFloat(max(max(model.targets.calories, model.consumed), 1))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Left to eat").fuelEyebrow()

      HStack(alignment: .lastTextBaseline, spacing: 12) {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
          Text(model.remaining, format: .number)
            .font(.fuelHeading(52, weight: 750))
            .foregroundStyle(Color.fuelInk)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
          Text("kcal")
            .font(.fuelMono(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelSubtle)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(model.consumed) eaten")
            .font(.fuelBody(.subheadline, weight: 600))
            .foregroundStyle(Color.fuelInk)
          if model.burned > 0 {
            Text("+\(model.burned) burned")
              .font(.fuelBody(.subheadline, weight: 600))
              .foregroundStyle(Color.fuelVoltInk)
          }
        }
        .contentTransition(.numericText())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
      }

      stackedBar

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        paceText
          .font(.fuelBody(.footnote))
          .foregroundStyle(paceColor)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 8)
        Text("goal \(model.targets.calories)")
          .font(.fuelMono(.footnote))
          .foregroundStyle(Color.fuelSubtle)
          .contentTransition(.numericText())
          .fixedSize()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .fuelCard()
  }

  // MARK: Stacked bar

  private var stackedBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.fuelInk.opacity(0.08))
        HStack(spacing: Self.gap) {
          ForEach(segments, id: \.type) { segment in
            Capsule()
              .fill(MealTypePalette.color(segment.type))
              .frame(width: width(of: segment.kcal, in: geo.size.width))
          }
          Spacer(minLength: 0)
        }
      }
      .clipShape(Capsule())
      .animation(.snappy, value: model.consumed)
    }
    .frame(height: 10)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Left to eat"))
    .accessibilityValue(Text("\(model.consumed) of \(model.targets.calories) kcal"))
  }

  private static let gap: CGFloat = 3

  private func width(of kcal: Int, in total: CGFloat) -> CGFloat {
    let gaps = Self.gap * CGFloat(max(segments.count - 1, 0))
    let usable = max(total - gaps, 0)
    return max(usable * CGFloat(kcal) / scale, 4)
  }

  // MARK: Pace

  /// The first section still empty, named in the "behind" nudge so the line
  /// says what to do rather than only how it's going.
  private var roomySection: String? {
    model.sections.first { $0.meals.isEmpty }?.type.label.lowercased()
  }

  private var paceText: Text {
    switch model.pace.status {
    case .over:
      return Text("Over goal — ease up tonight")
    case .ahead:
      return Text("Ahead of pace — nicely on track")
    case .behind:
      guard let roomySection else { return Text("A little behind — room to spare") }
      return Text("A little behind — \(roomySection) has room")
    case .on:
      return Text("Right on pace")
    }
  }

  private var paceColor: Color {
    model.pace.status == .over ? .fuelOverInk : .fuelSubtle
  }
}

// MARK: - Macro tile

// One third of the macro row: name, value against target, and a hairline bar in
// the macro's own color (protein green, carbs gold, fat terracotta).
private struct MacroTile: View {
  let name: LocalizedStringKey
  let value: Int
  let target: Int
  let fill: Color

  private var progress: Double {
    target > 0 ? min(Double(value) / Double(target), 1) : 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(name).fuelEyebrow()
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text("\(value)")
          .font(.fuelHeading(26, weight: 700))
          .foregroundStyle(Color.fuelInk)
          .contentTransition(.numericText())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text("/\(target)g")
          .font(.fuelMono(.caption))
          .foregroundStyle(Color.fuelSubtle)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.fuelInk.opacity(0.08))
          Capsule()
            .fill(fill)
            .frame(width: max(geo.size.width * progress, progress > 0 ? 4 : 0))
            .animation(.snappy, value: progress)
        }
      }
      .frame(height: 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .fuelCard()
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Meal section card

// One card per meal section, collapsed to a single line by default: colored dot,
// name, "2 items · 1:15 PM", kcal subtotal. Filled sections expand in place to
// their rows; empty ones are a direct "Add" into the section panel.
private struct MealSectionCard: View {
  let type: MealType
  let meals: [LoggedMeal]
  let isExpanded: Bool
  let onToggle: () -> Void
  let onAdd: () -> Void
  let onDelete: (LoggedMeal) -> Void

  private var isEmpty: Bool { meals.isEmpty }
  private var kcal: Int { meals.totals.calories }

  /// When this meal started — the earliest entry in the section, which reads
  /// more naturally than the most recent one ("Lunch · 1:15 PM").
  private var startedAt: String? {
    meals.map(\.loggedAt).min()?.formatted(date: .omitted, time: .shortened)
  }

  var body: some View {
    VStack(spacing: 0) {
      Button(action: isEmpty ? onAdd : onToggle) {
        collapsedRow
      }
      .buttonStyle(.plain)

      if isExpanded && !isEmpty {
        Rectangle()
          .fill(Color.fuelInk.opacity(0.06))
          .frame(height: 1)
          .padding(.horizontal, 16)
        expandedRows
      }
    }
    .fuelCard()
  }

  private var collapsedRow: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(isEmpty ? Color.fuelSubtle.opacity(0.35) : MealTypePalette.color(type))
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: 2) {
        Text(type.label)
          .font(.fuelHeading(17, weight: 700))
          .foregroundStyle(Color.fuelInk)
        subtitle
          .font(.fuelBody(.footnote))
          .foregroundStyle(Color.fuelSubtle)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      if isEmpty {
        Text("Add")
          .font(.fuelBody(.subheadline, weight: 700))
          .foregroundStyle(Color.fuelVoltInk)
      } else {
        HStack(spacing: 6) {
          Text("\(kcal) kcal")
            .font(.fuelHeading(15, weight: 700))
            .foregroundStyle(Color.fuelInk)
            .contentTransition(.numericText())
            .fixedSize()
          Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.fuelSubtle)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
      }
    }
    .padding(16)
    .frame(minHeight: 44)
    .contentShape(Rectangle())
  }

  private var subtitle: Text {
    guard let startedAt, !isEmpty else { return Text("Nothing yet · tap to add") }
    return meals.count == 1
      ? Text("\(meals.count) item · \(startedAt)")
      : Text("\(meals.count) items · \(startedAt)")
  }

  // The list, inside the card. Swipe-to-delete went away with the List; the
  // row's trash button and its long-press menu both still ask for confirmation.
  private var expandedRows: some View {
    VStack(spacing: 0) {
      ForEach(meals) { meal in
        MealRow(meal: meal, onDelete: { onDelete(meal) })
          .padding(.horizontal, 16)
          .padding(.vertical, 2)
          .contextMenu {
            Button(role: .destructive) {
              onDelete(meal)
            } label: {
              Label("Remove from log", systemImage: "trash")
            }
          }
      }

      Button(action: onAdd) {
        Text("+ Add")
          .font(.fuelBody(.footnote, weight: 600))
          .foregroundStyle(Color.fuelVoltInk)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
    }
    .padding(.top, 4)
    .padding(.bottom, 6)
  }
}

#Preview {
  TodayView()
    .environment(AppState())
}
