import Foundation
import Observation

// Drives the Coach tab. Two independent sections with their own lifecycles:
//   • Insights — the daily Gemini narrative, cached server-side per UTC day;
//     the toolbar refresh regenerates it (refresh=1).
//   • Suggestions — deterministic "what fits my remaining macros" ranking,
//     recomputed from today's log with a 10-minute bucketed client cache so a
//     nearby state reuses the last answer (matches the web's quota control).
// A 503 (unconfigured or rate-limited) collapses a section into a quiet
// "unavailable" card rather than an error banner, mirroring the web.
@MainActor
@Observable
final class CoachViewModel {
  enum SectionState<T: Equatable>: Equatable {
    case loading
    case ready(T)
    case unavailable
    case failed(PresentableError)
  }

  private(set) var insights: SectionState<AiInsights> = .loading
  private(set) var suggestions: SectionState<SuggestResponse> = .loading
  private(set) var remaining = RemainingMacros(calories: 0, protein: 0, carbs: 0, fat: 0)

  private(set) var isRefreshing = false
  private(set) var hasLoadedOnce = false

  var targets: Targets = TargetMath.defaultTargets

  private let repo = MealLogRepository()
  // 10-minute bucketed cache: bucketKey(lang) → response.
  private var suggestCache = PageCache<String, SuggestResponse>(staleness: 600)

  /// True while the very first load of either section is still in flight — used
  /// to drive the cold-start treatment.
  var isFirstLoading: Bool {
    !hasLoadedOnce && (insights == .loading || suggestions == .loading)
  }

  // MARK: - Loading

  func load(targets: Targets) async {
    self.targets = targets
    guard !hasLoadedOnce else { return }
    async let i: Void = loadInsights(refresh: false)
    async let s: Void = loadSuggestions(refresh: false)
    _ = await (i, s)
    hasLoadedOnce = true
  }

  /// The toolbar's global refresh — regenerate insights and bypass the
  /// suggestion cache.
  func refreshAll() async {
    isRefreshing = true
    defer { isRefreshing = false }
    async let i: Void = loadInsights(refresh: true)
    async let s: Void = loadSuggestions(refresh: true)
    _ = await (i, s)
  }

  func loadInsights(refresh: Bool) async {
    do {
      let data = try await FuelAPI.insights(refresh: refresh)
      insights = .ready(data)
    } catch {
      // Keep showing existing content if a refresh fails.
      if case .ready = insights { return }
      insights = Self.isUnavailable(error) ? .unavailable : .failed(PresentableError(error))
    }
  }

  func loadSuggestions(refresh: Bool) async {
    do {
      let meals = try await repo.meals(on: Date())
      let rem = RemainingMacros.clamp(targets: targets, totals: meals.totals)
      remaining = rem
      let key = rem.bucketKey(lang: AppLanguage.current)

      if !refresh, let cached = suggestCache.value(for: key) {
        suggestions = .ready(cached)
        return
      }
      let response = try await FuelAPI.suggestMeals(remaining: rem)
      suggestCache.store(response, for: key)
      suggestions = .ready(response)
    } catch {
      if case .ready = suggestions { return }
      suggestions = Self.isUnavailable(error) ? .unavailable : .failed(PresentableError(error))
    }
  }

  /// Called when a meal is logged elsewhere (logRevision bump): the remaining
  /// macros changed, so recompute suggestions (cache-first on the new bucket).
  func reloadSuggestionsForNewLog() async {
    await loadSuggestions(refresh: false)
  }

  func updateTargets(_ targets: Targets) {
    self.targets = targets
    Task { await loadSuggestions(refresh: false) }
  }

  // MARK: - Helpers

  // A 503 means AI is unconfigured or rate-limited — show a quiet card, not an
  // error. Everything else is a real failure worth a retry.
  private static func isUnavailable(_ error: Error) -> Bool {
    if let api = error as? APIError, case let .server(_, status) = api, status == 503 {
      return true
    }
    return false
  }
}
