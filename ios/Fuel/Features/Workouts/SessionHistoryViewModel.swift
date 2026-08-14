import Foundation
import Observation

// Drives "My workouts" — the last 30 days of COMPLETED sessions, newest first.
// Port of workouts/session/use-session-history.ts.
//
// There is no cache and no pagination here on purpose: the repository's history
// query embeds ids only, so 30 days is one small response, and a stale workout
// list is worse than a half-second refetch (you open this screen right after
// finishing a session to check it landed).
@MainActor
@Observable
final class SessionHistoryViewModel {
  private let repo = WorkoutSessionRepository()

  private(set) var sessions: [HistorySession] = []
  private(set) var isLoading = false
  private(set) var hasLoadedOnce = false
  var error: PresentableError?

  /// True only once a load has settled with nothing in it — so the empty state
  /// never flashes over a first load.
  var isEmpty: Bool { hasLoadedOnce && !isLoading && sessions.isEmpty }

  /// Skeletons belong to the FIRST load; a pull-to-refresh keeps the old rows.
  var showSkeleton: Bool { !hasLoadedOnce && isLoading }

  /// First appearance. Re-entering the tab keeps what's already loaded.
  func start() async {
    guard !hasLoadedOnce else { return }
    await refresh()
  }

  func refresh() async {
    isLoading = true
    defer {
      isLoading = false
      hasLoadedOnce = true
    }
    do {
      sessions = try await repo.history()
      error = nil
    } catch {
      self.error = PresentableError.presentable(error)
    }
  }
}
