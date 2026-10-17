import Foundation
import Observation

// State for the Workouts home tab: the in-progress session (resume banner) and
// the 30-day history that feeds the stat grid. Port of the data side of
// workouts-home.tsx (use-in-progress-session.ts + use-session-history.ts).
@MainActor
@Observable
final class WorkoutsHomeViewModel {
  private let repository = WorkoutSessionRepository()

  private(set) var inProgress: WorkoutSession?
  private(set) var history: [HistorySession] = []
  private(set) var isRefreshing = false
  private(set) var hasLoadedOnce = false
  var error: PresentableError?

  var showSkeleton: Bool { !hasLoadedOnce && isRefreshing }

  /// True when the running session was started so long ago (12h+) that it was
  /// obviously forgotten, not paused — the banner swaps its ticking timer for
  /// an "end this old session?" prompt.
  var inProgressIsStale: Bool {
    guard let inProgress else { return false }
    return SessionStats.isStaleInProgress(startedAt: inProgress.startedAt)
  }

  // MARK: - Stats (the 2×2 grid)

  var sessionsThisWeek: Int {
    WorkoutHistoryStats.sessionsThisWeek(history, now: Date())
  }

  var sessionsLast30Days: Int { history.count }

  var lastSession: HistorySession? {
    WorkoutHistoryStats.lastSession(history)
  }

  // MARK: - Loading

  func start() async {
    guard !hasLoadedOnce else { return }
    await refresh()
  }

  func refresh() async {
    isRefreshing = true
    defer {
      isRefreshing = false
      hasLoadedOnce = true
    }
    do {
      async let inProgressResult = repository.inProgressSession()
      async let historyResult = repository.history()
      let (current, past) = try await (inProgressResult, historyResult)
      inProgress = current
      history = past
      error = nil
    } catch {
      self.error = PresentableError.presentable(error)
    }
  }

  /// Complete the forgotten session with its stored duration capped at the
  /// display cap (ended_at = started_at + 6h, so the timestamps and
  /// duration_seconds stay consistent) — the "End this old session?" action.
  @discardableResult
  func endStaleSession() async -> Bool {
    guard let current = inProgress else { return false }
    let cappedEnd = min(
      Date(),
      current.startedAt.addingTimeInterval(TimeInterval(DurationFormat.displayCapSeconds))
    )
    do {
      try await repository.endSession(id: current.id, startedAt: current.startedAt, endedAt: cappedEnd)
      inProgress = nil
      await refresh()
      return true
    } catch {
      self.error = PresentableError.presentable(error)
      return false
    }
  }
}
