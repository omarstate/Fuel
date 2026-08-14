import Foundation
import Observation

// Drives the Library tab. Holds the loaded page for the current (category,
// search, mine) query, an in-memory PageCache with 5-minute staleness so
// switching filters back and forth is instant, and the infinite-scroll cursor.
// `invalidate()` clears the cache after any catalog mutation, exactly like the
// web's `invalidateMealsCache`.
@MainActor
@Observable
final class LibraryViewModel {
  // The accumulated result for one query — cached and restored wholesale.
  struct PageState {
    var items: [CatalogMeal]
    var total: Int
    var nextOffset: Int
    var canLoadMore: Bool
  }

  // Inputs (driven by the view).
  var searchText = ""
  var category: Category?
  var mine = false

  // Outputs.
  private(set) var meals: [CatalogMeal] = []
  private(set) var total = 0
  private(set) var categories: [Category] = []
  private(set) var isLoading = false
  private(set) var isLoadingMore = false
  private(set) var hasLoadedOnce = false
  var error: PresentableError?

  private var nextOffset = 0
  private var canLoadMore = false
  private var cache = PageCache<CatalogQuery, PageState>()
  private var debounceTask: Task<Void, Never>?

  private let pageSize = 30

  // MARK: - Derived

  /// The query identity for the current filter state. In "mine" mode the search
  /// is applied client-side, so it doesn't participate in the server query key.
  var query: CatalogQuery {
    CatalogQuery(
      category: mine ? nil : category?.slug,
      search: mine ? "" : trimmedSearch,
      mine: mine
    )
  }

  private var trimmedSearch: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// What the list renders. "Mine" filters locally by name; catalog mode already
  /// filtered server-side.
  var displayedMeals: [CatalogMeal] {
    guard mine, !trimmedSearch.isEmpty else { return meals }
    let needle = trimmedSearch.lowercased()
    return meals.filter { $0.name.lowercased().contains(needle) }
  }

  var showLoadMore: Bool { !mine && canLoadMore }
  var isEmpty: Bool { hasLoadedOnce && !isLoading && displayedMeals.isEmpty }

  // MARK: - Lifecycle

  /// First appearance: load categories (once) then the initial page.
  func start() async {
    if categories.isEmpty {
      categories = (try? await FuelAPI.categories()) ?? []
    }
    await reload()
  }

  /// Debounced reload for `.searchable` text changes (~300ms).
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

  /// Fetch the next page in catalog mode when the last row appears.
  func loadMore() async {
    guard !mine, canLoadMore, !isLoadingMore, !isLoading else { return }
    let key = query
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let state = try await fetch(query: key, offset: nextOffset, existing: meals)
      guard key == query else { return }
      apply(state)
      cache.store(state, for: key)
    } catch {
      guard key == query else { return }
      self.error = PresentableError.presentable(error)
    }
  }

  /// Drop all cached pages after a catalog mutation, then reload the current view.
  func invalidate() async {
    cache.invalidate()
    await fetchFirstPage(key: query)
  }

  // MARK: - Fetching

  private func fetchFirstPage(key: CatalogQuery) async {
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

  private func fetch(query key: CatalogQuery, offset: Int, existing: [CatalogMeal]) async throws -> PageState {
    if key.mine {
      let items = try await FuelAPI.myMeals()
      return PageState(items: items, total: items.count, nextOffset: items.count, canLoadMore: false)
    }
    let (page, count) = try await FuelAPI.meals(
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
    meals = state.items
    total = state.total
    nextOffset = state.nextOffset
    canLoadMore = state.canLoadMore
    error = nil
  }
}
