import Foundation
import Observation

// The identity of a Workout Library query: which category (nil = All) by SLUG,
// and the trimmed search text. Lives here rather than next to CatalogQuery in
// Core/Logic/PageCache.swift because PageCache is already generic over its key —
// there is nothing to add to that file.
struct WorkoutQuery: Hashable, Sendable {
  /// A category SLUG (what GET /workouts filters on), not an id.
  var category: String?
  var search: String

  init(category: String? = nil, search: String = "") {
    self.category = category
    self.search = search
  }
}

// Drives the Workout Library tab — the shared exercise catalog, paginated
// server-side. Deliberately a close mirror of LibraryViewModel (meals): same
// PageCache discipline, same 300ms debounce, same `guard key == query` after
// every await so a slow response for an abandoned filter can't overwrite the
// screen.
//
// Divergence from the web's workout-library.tsx: it fetches EVERY workout via
// /workouts/grouped and filters in the browser. On a phone that's a large cold
// payload for a list you scroll a page of, so this uses the paginated
// /workouts route (search + category are server-side) exactly like the meals
// Library.
@MainActor
@Observable
final class WorkoutLibraryViewModel {
  // The accumulated result for one query — cached and restored wholesale.
  struct PageState {
    var items: [Workout]
    var total: Int
    var nextOffset: Int
    var canLoadMore: Bool
  }

  // Inputs (driven by the view).
  var searchText = ""
  var category: WorkoutCategory?

  // Outputs.
  private(set) var workouts: [Workout] = []
  private(set) var total = 0
  private(set) var categories: [WorkoutCategory] = []
  private(set) var isLoading = false
  private(set) var isLoadingMore = false
  private(set) var hasLoadedOnce = false
  var error: PresentableError?

  private var nextOffset = 0
  private var canLoadMore = false
  private var cache = PageCache<WorkoutQuery, PageState>()
  private var debounceTask: Task<Void, Never>?

  private let pageSize = 30

  // MARK: - Derived

  var query: WorkoutQuery {
    WorkoutQuery(category: category?.slug, search: trimmedSearch)
  }

  private var trimmedSearch: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var isEmpty: Bool { hasLoadedOnce && !isLoading && workouts.isEmpty }
  var showSkeleton: Bool { !hasLoadedOnce && isLoading }

  // MARK: - Lifecycle

  /// First appearance: load categories (once) then the initial page.
  func start() async {
    if categories.isEmpty {
      categories = (try? await FuelAPI.workoutCategories()) ?? []
    }
    await reload()
  }

  /// Debounced reload for search-text changes (~300ms).
  func searchTextChanged() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      await self?.reload()
    }
  }

  /// Load page 0 for the current query, restoring from cache when fresh.
  func reload() async {
    let key = query
    if let cached = cache.value(for: key) {
      apply(cached)
      hasLoadedOnce = true
      return
    }
    await fetchFirstPage(key: key)
  }

  /// Force a network refresh of the current query (pull-to-refresh).
  func refresh() async {
    cache.invalidate(query)
    await fetchFirstPage(key: query)
  }

  /// Fetch the next page when the last row appears.
  func loadMore() async {
    guard canLoadMore, !isLoadingMore, !isLoading else { return }
    let key = query
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let state = try await fetch(query: key, offset: nextOffset, existing: workouts)
      guard key == query else { return }
      apply(state)
      cache.store(state, for: key)
    } catch {
      guard key == query else { return }
      self.error = PresentableError.presentable(error)
    }
  }

  /// Drop all cached pages after a catalog mutation, then reload the current
  /// view — the equivalent of the web's `invalidateMealsCache`.
  func invalidate() async {
    cache.invalidate()
    await fetchFirstPage(key: query)
  }

  // MARK: - Fetching

  private func fetchFirstPage(key: WorkoutQuery) async {
    isLoading = true
    error = nil
    defer {
      isLoading = false
      hasLoadedOnce = true
    }
    do {
      let state = try await fetch(query: key, offset: 0, existing: [])
      guard key == query else { return }
      apply(state)
      cache.store(state, for: key)
    } catch {
      guard key == query else { return }
      self.error = PresentableError.presentable(error)
    }
  }

  private func fetch(query key: WorkoutQuery, offset: Int, existing: [Workout]) async throws -> PageState {
    let (page, count) = try await FuelAPI.workouts(
      category: key.category,
      search: key.search,
      limit: pageSize,
      offset: offset
    )
    let combined = existing + page
    return PageState(
      items: combined,
      total: count,
      nextOffset: combined.count,
      canLoadMore: combined.count < count && !page.isEmpty
    )
  }

  private func apply(_ state: PageState) {
    workouts = state.items
    total = state.total
    nextOffset = state.nextOffset
    canLoadMore = state.canLoadMore
    error = nil
  }
}
