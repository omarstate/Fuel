import SwiftUI

// The tab home once signed in and onboarded — one of TWO tab sets, depending
// on which SIDE of the app is active (AppState.side): nutrition (Today /
// History / Library / More) or workouts (Home / History / Library / More).
// The sides swap wholesale, mirroring the web app's sidebar mode toggle; the
// SideSwitcher in each side's home header flips between them.
//
// The bottom bar is the STOCK iOS 26 tab bar — system Liquid Glass, with the
// system's own selection morph. An earlier revision hand-built the bar from
// `GlassEffectContainer` + `glassEffectID` so the selected pill could metaball
// between tabs, but the custom spring never matched the system feel and it
// forfeited what the stock bar does for free (safe-area propagation, the real
// glass response, accessibility). Don't resurrect it — DESIGN.md rule 1 is
// system-first.
//
// The plus rides along as a `role: .search` tab, which the system renders as
// the separated trailing glass circle beside the tab capsule. It is never
// allowed to actually become the selection: the binding below intercepts the
// tap — on the nutrition side it opens the log chooser, on the workouts side
// it starts (or resumes) a session — so the bar's indicator never leaves the
// real tab and the pseudo-tab's content never shows.
struct MainTabView: View {
  @Environment(AppState.self) private var app
  @State private var selection: HomeTab = .today
  @State private var showLogChooser = false

  var body: some View {
    TabView(selection: barSelection) {
      switch app.side {
      case .nutrition:
        Tab("Today", systemImage: HomeTab.today.systemImage, value: HomeTab.today) {
          TodayView()
        }
        Tab("History", systemImage: HomeTab.history.systemImage, value: HomeTab.history) {
          HistoryView()
        }
        Tab("Library", systemImage: HomeTab.library.systemImage, value: HomeTab.library) {
          LibraryView()
        }
      case .workouts:
        Tab("Home", systemImage: HomeTab.workoutsHome.systemImage, value: HomeTab.workoutsHome) {
          WorkoutsHomeView()
        }
        Tab("History", systemImage: HomeTab.workoutsHistory.systemImage, value: HomeTab.workoutsHistory) {
          SessionHistoryView()
        }
        Tab("Library", systemImage: HomeTab.workoutsLibrary.systemImage, value: HomeTab.workoutsLibrary) {
          WorkoutLibraryView()
        }
      }
      Tab("More", systemImage: HomeTab.more.systemImage, value: HomeTab.more) {
        MoreView()
      }
      // The plus. Content is never rendered — selection is intercepted.
      Tab(plusLabel, systemImage: "plus", value: HomeTab.log, role: .search) {
        Color.clear
      }
    }
    // Selection must stay valid when the side (and with it the tab set) swaps —
    // and on first appearance, since the persisted side may be workouts while
    // the initial @State selection is nutrition's home.
    .onChange(of: app.side) { _, side in
      withAnimation(.snappy) {
        selection = (side == .workouts) ? .workoutsHome : .today
      }
    }
    .onAppear {
      if app.side == .workouts { selection = .workoutsHome }
    }
    // The touch path to the log actions: an invisible Menu sitting exactly on
    // the bar's plus circle, so the options pop up anchored on the plus itself.
    // A centered confirmationDialog was tried and vetoed — it blocked the
    // content behind it.
    .overlay(alignment: .bottomTrailing) {
      if app.side == .nutrition { logMenu }
    }
    // VoiceOver/fallback path only: activating the underlying pseudo-tab (which
    // the Menu overlay covers for touch) still offers every action.
    .confirmationDialog("Log a meal", isPresented: $showLogChooser, titleVisibility: .visible) {
      logActions
    }
  }

  // Every add entry point, behind the plus (nutrition side). All of them log
  // to today; barcode opens its own chooser — quick-log the scan into today,
  // or add the product to the shared catalog. Voice leads — it's the fastest
  // way to log and the hero feature. AI lookup is deliberately absent: it
  // overlapped with AI estimate in users' minds; catalog lookup lives in the
  // Library.
  @ViewBuilder
  private var logActions: some View {
    Button { request(.manual) } label: {
      Label("Add manually", systemImage: "square.and.pencil")
    }
    Section {
      ForEach([LogAction.voice, .estimate, .photo, .barcode]) { kind in
        Button { request(.action(kind)) } label: {
          Label(kind.title, systemImage: kind.systemImage)
        }
      }
    }
  }

  // Laid over the system-drawn plus circle. The frame/paddings are tuned to
  // the stock bar's search-slot metrics (verified on device); revisit if the
  // system bar geometry ever changes.
  private var logMenu: some View {
    Menu {
      logActions
    } label: {
      Color.clear
        .frame(width: 64, height: 64)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .padding(.trailing, 20)
    .offset(y: 14)
    .accessibilityHidden(true) // VoiceOver uses the real tab item underneath.
  }

  private var plusLabel: LocalizedStringKey {
    app.side == .workouts ? "Start" : "Log"
  }

  /// Routes taps on the plus pseudo-tab to the side's primary action without
  /// ever moving the bar's selection off the current tab (so nothing flashes
  /// underneath). Nutrition: the meal-log chooser. Workouts: straight into
  /// start-or-resume — one action, no chooser needed.
  private var barSelection: Binding<HomeTab> {
    Binding(
      get: { selection },
      set: { tapped in
        if tapped == .log {
          switch app.side {
          case .nutrition:
            showLogChooser = true
          case .workouts:
            requestWorkout(.startSession)
          }
        } else {
          selection = tapped
        }
      }
    )
  }

  // The sheets live in TodayView, so jump there first and hand off the request.
  private func request(_ requested: AppState.LogRequest) {
    selection = .today
    app.pendingLogRequest = requested
  }

  // Same hand-off for the workouts side — its sheets live on the Workouts home.
  private func requestWorkout(_ intent: AppState.WorkoutIntent) {
    selection = .workoutsHome
    app.pendingWorkoutIntent = intent
  }
}

// MARK: - Tabs

enum HomeTab: Hashable {
  // Nutrition side.
  case today
  case history
  case library
  // Workouts side.
  case workoutsHome
  case workoutsHistory
  case workoutsLibrary
  // Both sides.
  case more
  /// Not a destination — the plus action slot in the bar.
  case log

  var systemImage: String {
    switch self {
    case .today: return "flame.fill"
    case .history: return "calendar"
    case .library: return "books.vertical.fill"
    case .workoutsHome: return "figure.strengthtraining.traditional"
    case .workoutsHistory: return "calendar"
    case .workoutsLibrary: return "list.bullet.rectangle"
    case .more: return "ellipsis"
    case .log: return "plus"
    }
  }
}

#Preview {
  MainTabView()
    .environment(AppState())
}
