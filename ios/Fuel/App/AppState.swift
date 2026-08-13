import Foundation
import Observation
import Supabase

// The single app-wide state object, placed in the environment. Drives which
// top-level surface RootView shows.
@MainActor
@Observable
final class AppState {
  enum Phase: Equatable {
    case loading
    case signedOut
    case needsOnboarding
    case ready
  }

  private(set) var phase: Phase = .loading
  private(set) var me: Me?
  private(set) var profile: Profile?
  /// The user's display name from auth metadata (mirrors the web app). Editable
  /// from the Profile tab's Personal data card.
  private(set) var displayName: String?

  /// Set while the initial user fetch is in flight (drives cold-start overlay).
  private(set) var isBootstrapping = false
  /// A recoverable error during bootstrap (network / cold start) — RootView
  /// offers a retry rather than dumping the user back to sign-in.
  var bootstrapError: PresentableError?

  /// Server-persisted targets, falling back to DEFAULT_TARGETS with no profile.
  var targets: Targets { profile?.targets ?? TargetMath.defaultTargets }

  /// A lightweight cross-tab freshness signal, bumped after ANY meal-log write
  /// (add / quick-log / AI estimate / delete). Today, History and the Coach's
  /// suggestions observe it and reload so a log from one surface reflects
  /// everywhere immediately.
  private(set) var logRevision = 0

  func bumpLogRevision() { logRevision += 1 }

  /// The workout twin of `logRevision`, deliberately separate: three meal
  /// surfaces refetch on every `logRevision` bump, and a set logged mid-workout
  /// shouldn't trigger any of them.
  private(set) var workoutRevision = 0

  func bumpWorkoutRevision() { workoutRevision += 1 }

  // MARK: - App side

  /// Which side of the app the tab bar shows — nutrition or workouts. The two
  /// are separate surfaces with their own tab sets and accent (green vs orange),
  /// mirroring the web app's sidebar mode toggle. Persisted so the app reopens
  /// on the side you left it.
  enum AppSide: String, CaseIterable {
    case nutrition
    case workouts
  }

  var side: AppSide = AppSide(
    rawValue: UserDefaults.standard.string(forKey: "fuel.side") ?? ""
  ) ?? .nutrition {
    didSet { UserDefaults.standard.set(side.rawValue, forKey: "fuel.side") }
  }

  /// A workout flow picked from the global bottom bar's plus (workouts side).
  /// Same park-and-forward pattern as `pendingLogRequest`, but the Workouts
  /// home owns the session sheets, so it lands there instead of TodayView.
  enum WorkoutIntent: Equatable {
    case startSession
  }

  var pendingWorkoutIntent: WorkoutIntent?

  /// A log flow picked from the global bottom bar. The bar lives above the tab
  /// content, so it parks the request here and TodayView (which owns the meal
  /// log + its view model) presents the matching sheet.
  enum LogRequest: Equatable, Identifiable {
    case manual
    case action(LogAction)

    var id: String {
      switch self {
      case .manual: return "manual"
      case .action(let kind): return kind.rawValue
      }
    }
  }

  var pendingLogRequest: LogRequest?

  private var authObservationTask: Task<Void, Never>?

  // MARK: - Lifecycle

  /// Called once from the app entry point.
  func start() {
    // Warm the Render backend early so the first real request isn't a cold start.
    Task { await FuelAPI.warmUp() }
    observeAuth()
  }

  private func observeAuth() {
    guard authObservationTask == nil else { return }
    authObservationTask = Task { [weak self] in
      for await (event, session) in SupabaseService.shared.authStateChanges {
        await self?.handle(event: event, session: session)
      }
    }
  }

  private func handle(event: AuthChangeEvent, session: Session?) async {
    switch event {
    case .initialSession, .signedIn:
      if session != nil {
        await loadUserData()
      } else {
        setSignedOut()
      }
    case .signedOut:
      setSignedOut()
    default:
      // tokenRefreshed / userUpdated / passwordRecovery — no phase change.
      break
    }
  }

  // MARK: - User data

  /// Fetches GET /me + GET /profile and derives the phase.
  func loadUserData() async {
    isBootstrapping = true
    bootstrapError = nil
    defer { isBootstrapping = false }
    do {
      async let meResult = FuelAPI.me()
      async let profileResult = FuelAPI.profile()
      let me = try await meResult
      let profile = try await profileResult
      self.me = me
      self.profile = profile
      self.displayName = SupabaseService.shared.displayName
      self.phase = (profile == nil) ? .needsOnboarding : .ready
    } catch APIError.unauthorized {
      // Token no longer valid — treat as signed out.
      try? await SupabaseService.shared.signOut()
      setSignedOut()
    } catch {
      bootstrapError = PresentableError(error)
      if phase != .ready { phase = .loading }
    }
  }

  /// Re-fetch the profile after onboarding / profile save without a full reload.
  func refreshProfile() async {
    do {
      let profile = try await FuelAPI.profile()
      self.profile = profile
      self.phase = (profile == nil) ? .needsOnboarding : .ready
    } catch {
      bootstrapError = PresentableError(error)
    }
  }

  /// Apply a Profile returned directly from PUT /profile (onboarding / save).
  func applyProfile(_ profile: Profile) {
    self.profile = profile
    self.phase = .ready
  }

  /// Reflect a display-name change made from the Profile tab.
  func applyDisplayName(_ name: String?) {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.displayName = (trimmed?.isEmpty ?? true) ? nil : trimmed
  }

  // MARK: - Auth actions

  func signOut() async {
    try? await SupabaseService.shared.signOut()
    // authStateChanges will drive setSignedOut, but do it eagerly too.
    setSignedOut()
  }

  /// Local teardown after DELETE /me succeeds server-side.
  func handleAccountDeleted() async {
    try? await SupabaseService.shared.signOut()
    setSignedOut()
  }

  private func setSignedOut() {
    me = nil
    profile = nil
    displayName = nil
    bootstrapError = nil
    phase = .signedOut
  }
}
