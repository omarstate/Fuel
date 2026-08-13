import SwiftUI

// The Workouts home tab — the landing screen of the workouts side. Port of
// app-editorial/workouts-home.tsx: a resume banner when a session is running,
// one dominant "Start session" hero, and a 2×2 stat grid. The web page's
// secondary links to History/Library don't port — those are tabs here.
//
// This screen also owns the session sheets (start picker, the full-screen
// active session, the post-session summary), the way TodayView owns the meal
// log sheets: the tab bar parks a WorkoutIntent on AppState and this view
// presents the matching surface.
struct WorkoutsHomeView: View {
  @Environment(AppState.self) private var app
  @Environment(\.scenePhase) private var scenePhase

  @State private var model = WorkoutsHomeViewModel()
  @State private var showStartSheet = false
  @State private var activeSession: SessionRoute?
  /// Set by the start sheet, presented from its onDismiss — presenting the
  /// full-screen cover while the sheet is still animating out silently drops
  /// the presentation, leaving a running session with no screen.
  @State private var pendingActiveSession: SessionRoute?
  @State private var summarySession: SessionRoute?
  /// Bumped on pull-to-refresh so the Health strip re-reads with the sessions.
  @State private var activityRefresh = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          header

          if let error = model.error {
            ErrorBanner(
              error: error,
              onRetry: { Task { await model.refresh() } },
              onDismiss: { model.error = nil }
            )
          }

          if let session = model.inProgress {
            resumeBanner(session)
          } else {
            startHero
          }

          // Live Health numbers (watch/phone): heart rate, burned, steps.
          TodayActivityStrip(refreshTrigger: activityRefresh)

          statGrid
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .background(Color.fuelBackground)
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar(.hidden, for: .navigationBar)
      .statusBarFade()
      .refreshable {
        activityRefresh &+= 1
        await model.refresh()
      }
    }
    .task { await model.start() }
    .onChange(of: app.workoutRevision) { Task { await model.refresh() } }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refresh() } }
    }
    // The bar's plus parks an intent here (same hand-off as pendingLogRequest).
    .onChange(of: app.pendingWorkoutIntent) { _, intent in
      guard let intent else { return }
      switch intent {
      case .startSession:
        // A running session takes priority — the plus resumes it rather than
        // stacking a second in_progress row.
        if let current = model.inProgress {
          activeSession = SessionRoute(id: current.id)
        } else {
          showStartSheet = true
        }
      }
      app.pendingWorkoutIntent = nil
    }
    .sheet(isPresented: $showStartSheet, onDismiss: {
      if let route = pendingActiveSession {
        pendingActiveSession = nil
        activeSession = route
      }
    }) {
      StartSessionSheet { newId in
        pendingActiveSession = SessionRoute(id: newId)
        app.bumpWorkoutRevision()
      }
    }
    .fullScreenCover(item: $activeSession) { route in
      ActiveSessionView(sessionId: route.id) { endedId in
        activeSession = nil
        summarySession = SessionRoute(id: endedId)
        app.bumpWorkoutRevision()
      }
    }
    // The post-session summary — the read-only detail in a sheet, so ending a
    // session lands on its numbers instead of dumping straight back home.
    .sheet(item: $summarySession) { route in
      NavigationStack { SessionDetailView(sessionId: route.id) }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        Text(FuelDateFormat.eyebrow(Date())).fuelEyebrow(color: .fuelWorkoutInk)
        Spacer(minLength: 8)
        SideSwitcher()
      }
      Text("Workouts")
        .font(.fuelMasthead)
        .foregroundStyle(Color.fuelInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.bottom, 2)
  }

  // MARK: - Resume banner

  private func resumeBanner(_ session: WorkoutSession) -> some View {
    Button {
      activeSession = SessionRoute(id: session.id)
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Circle()
              .fill(Color.fuelWorkout)
              .frame(width: 7, height: 7)
            Text("In progress").fuelEyebrow(color: .fuelWorkoutInk)
          }
          Text(session.categoryName ?? String(localized: "Workout"))
            .font(.fuelBody(.title3, weight: 600))
            .foregroundStyle(Color.fuelInk)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 4) {
          SessionTimerView(startedAt: session.startedAt, font: .fuelMetric, color: .fuelWorkoutInk)
          Text("Tap to resume")
            .font(.fuelBody(.footnote))
            .foregroundStyle(Color.fuelSubtle)
        }
      }
      .padding(16)
      .background(Color.fuelWorkout.opacity(0.1))
      .fuelCard()
      .contentShape(RoundedRectangle(cornerRadius: FuelRadius.card, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Start hero

  private var startHero: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Ready to train?").fuelEyebrow(color: .fuelWorkoutInk)
        Text("Log your next session")
          .font(.fuelTitle2)
          .foregroundStyle(Color.fuelInk)
      }
      Button {
        showStartSheet = true
      } label: {
        Label("Start session", systemImage: "play.fill")
          .font(.fuelBody(.body, weight: 600))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }
      .buttonStyle(.glassProminent)
      .tint(.fuelWorkout)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
    .redacted(reason: model.showSkeleton ? .placeholder : [])
  }

  // MARK: - Stats

  private var statGrid: some View {
    LazyVGrid(
      columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
      spacing: 12
    ) {
      StatTile(label: "This week", value: "\(model.sessionsThisWeek)", unit: "sessions")
      StatTile(label: "Last 30 days", value: "\(model.sessionsLast30Days)", unit: "sessions")
      StatTile(label: "Last session", value: lastSessionText)
      StatTile(label: "Last type", value: model.lastSession?.categoryName ?? "—")
    }
    .redacted(reason: model.showSkeleton ? .placeholder : [])
  }

  private var lastSessionText: String {
    guard let last = model.lastSession else { return "—" }
    switch WorkoutHistoryStats.relativeDay(last.startedAt, now: Date()) {
    case .today: return String(localized: "Today")
    case .yesterday: return String(localized: "Yesterday")
    case .daysAgo(let n): return String(localized: "\(n)d ago")
    case .weeksAgo(let n): return String(localized: "\(n)w ago")
    }
  }
}

/// Identifiable wrapper so a bare session UUID can drive `.fullScreenCover(item:)`
/// and `.sheet(item:)` without a retroactive `UUID: Identifiable` conformance.
private struct SessionRoute: Identifiable {
  let id: UUID
}

#Preview {
  WorkoutsHomeView()
    .environment(AppState())
}
