import SwiftUI

// The four-tab home once signed in and onboarded.
//
// The bottom bar is a CUSTOM Liquid Glass bar rather than the stock tab bar, for
// one reason the system bar can't give us: the selected pill has to MORPH — that
// gooey, chromatic "metaball" stretch as it travels between tabs (the effect in
// every iOS 26 app). That comes from a `glassEffectID` pill animating inside a
// `GlassEffectContainer`; the stock `TabView` bar only cross-fades its
// indicator. The primary "log meal" action sits beside the capsule as its own
// citrus disc — two siblings in one container so the glass blends correctly.
// Coach was pulled from the bar — `CoachView` still exists but is unrouted.
struct MainTabView: View {
  @Environment(AppState.self) private var app
  @State private var selection: HomeTab = .today
  @Namespace private var glassNS
  /// Measured capsule width — needed to map a drag's x position to a tab slot so
  /// the selection follows the finger, morphing continuously as it crosses tabs.
  @State private var capsuleWidth: CGFloat = 0

  private static let barHeight: CGFloat = 56
  private static let plusSize: CGFloat = 58

  var body: some View {
    TabView(selection: $selection) {
      // `.toolbar(.hidden, for: .tabBar)` on each tab's CONTENT suppresses the
      // stock bar so only our custom morphing one draws.
      Tab("Today", systemImage: HomeTab.today.systemImage, value: HomeTab.today) {
        TodayView().hideSystemTabBar()
      }
      Tab("History", systemImage: HomeTab.history.systemImage, value: HomeTab.history) {
        HistoryView().hideSystemTabBar()
      }
      Tab("Library", systemImage: HomeTab.library.systemImage, value: HomeTab.library) {
        LibraryView().hideSystemTabBar()
      }
      Tab("Profile", systemImage: HomeTab.profile.systemImage, value: HomeTab.profile) {
        ProfileView().hideSystemTabBar()
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      bottomBar.padding(.bottom, 4)
    }
  }

  // MARK: - Bottom bar

  private var bottomBar: some View {
    // One container so the tab capsule and the plus disc share a glass field and
    // the selection pill can morph. `spacing` sets how close glass shapes must be
    // to merge — tuned so the pill stretches fluidly between adjacent tabs.
    GlassEffectContainer(spacing: 16) {
      HStack(spacing: 10) {
        tabCapsule
        logMenu
      }
      .padding(.horizontal, 16)
    }
  }

  private var tabCapsule: some View {
    HStack(spacing: 0) {
      ForEach(HomeTab.allCases) { tab in
        tabItem(tab)
      }
    }
    .frame(height: Self.barHeight)
    // The translucent bar itself. `.interactive()` makes it flex under touch.
    .glassEffect(.regular.interactive(), in: .capsule)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { capsuleWidth = $0 }
    // One gesture for the whole capsule (not a Button per tab, which would eat
    // the touch and kill the drag): the selection follows the finger, so the
    // glass pill morphs continuously as it slides across tabs. minimumDistance 0
    // means this still handles plain taps.
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { select(atX: $0.location.x) }
        .onEnded { select(atX: $0.location.x) }
    )
    .sensoryFeedback(.selection, trigger: selection)
  }

  /// Maps a touch's x position to the tab slot under it.
  private func select(atX x: CGFloat) {
    guard capsuleWidth > 0 else { return }
    let tabs = HomeTab.allCases
    let slot = capsuleWidth / CGFloat(tabs.count)
    let index = min(max(Int(x / slot), 0), tabs.count - 1)
    let tab = tabs[index]
    guard tab != selection else { return }
    // A springy animation is what makes the glass pill stretch/settle as it
    // morphs to the new slot rather than snapping.
    withAnimation(.smooth(duration: 0.4, extraBounce: 0.15)) { selection = tab }
  }

  private func tabItem(_ tab: HomeTab) -> some View {
    let active = selection == tab
    return VStack(spacing: 3) {
      Image(systemName: tab.systemImage)
        .font(.system(size: 18, weight: active ? .semibold : .regular))
      Text(tab.title)
        .font(.fuelBody(.caption2, weight: active ? 600 : 500))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .foregroundStyle(active ? Color.fuelVoltInk : Color.fuelSubtle)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // The selection pill: a brighter glass capsule INSET from the bar edges,
    // carrying `glassEffectID` so it MORPHS between tabs inside the container
    // (the metaball stretch) instead of cross-fading. The accent stays on the
    // icon/label; the pill itself is neutral glass, exactly as the system does.
    .background {
      if active {
        Capsule()
          .fill(.clear)
          .glassEffect(.regular.interactive(), in: .capsule)
          .glassEffectID("tabPill", in: glassNS)
          .padding(.vertical, 6)
          .padding(.horizontal, 4)
      }
    }
    .contentShape(.rect)
    // The capsule owns the gesture, so each item carries its own a11y action.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(tab.title)
    .accessibilityAddTraits(active ? [.isButton, .isSelected] : [.isButton])
    .accessibilityAction { selection = tab }
  }

  // Every log entry point, behind one plus. Solid citrus (not glass) so it reads
  // as the single primary action and stays distinct from the tab capsule.
  private var logMenu: some View {
    Menu {
      Button { request(.manual) } label: {
        Label("Add manually", systemImage: "square.and.pencil")
      }
      Section {
        // Voice comes first — it's the fastest way to log and the hero feature.
        // AI lookup is deliberately absent — it overlapped with AI estimate in
        // users' minds; catalog lookup lives in the Library.
        ForEach([LogAction.voice, .estimate, .photo, .barcode]) { kind in
          Button { request(.action(kind)) } label: {
            Label(kind.title, systemImage: kind.systemImage)
          }
        }
      }
    } label: {
      Image(systemName: "plus")
        .font(.system(size: 23, weight: .bold))
        .foregroundStyle(Color.fuelBackground)
        .frame(width: Self.plusSize, height: Self.plusSize)
        .background(Color.fuelVolt, in: .circle)
        .shadow(color: Color.fuelVolt.opacity(0.35), radius: 12, y: 3)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("Log meal"))
  }

  // The sheets live in TodayView, so jump there first and hand off the request.
  private func request(_ requested: AppState.LogRequest) {
    selection = .today
    app.pendingLogRequest = requested
  }
}

private extension View {
  func hideSystemTabBar() -> some View {
    toolbarVisibility(.hidden, for: .tabBar)
  }
}

// MARK: - Tabs

enum HomeTab: Hashable, CaseIterable, Identifiable {
  case today
  case history
  case library
  case profile

  var id: Self { self }

  var title: LocalizedStringKey {
    switch self {
    case .today: return "Today"
    case .history: return "History"
    case .library: return "Library"
    case .profile: return "Profile"
    }
  }

  var systemImage: String {
    switch self {
    case .today: return "flame.fill"
    case .history: return "calendar"
    case .library: return "books.vertical.fill"
    case .profile: return "person.crop.circle"
    }
  }
}

#Preview {
  MainTabView()
    .environment(AppState())
}
