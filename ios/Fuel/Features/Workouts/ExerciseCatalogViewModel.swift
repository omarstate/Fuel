import Foundation
import Observation

// The identity of one exercise-catalog query: trimmed search plus the two
// filters. Same role WorkoutQuery plays for the Library — two queries that
// would return the same page share a PageCache entry.
struct ExerciseCatalogQuery: Hashable, Sendable {
  var search: String
  /// Dataset `category` ("strength", "cardio", …), nil = All.
  var category: String?
  /// Dataset primary-muscle spelling ("lower back"), nil = All.
  var muscle: String?

  init(search: String = "", category: String? = nil, muscle: String? = nil) {
    self.search = search
    self.category = category
    self.muscle = muscle
  }
}

// Drives the "Browse exercises" sheet over the mirrored free-exercise-db
// dataset (~870 rows). A close mirror of WorkoutLibraryViewModel — same
// PageCache discipline, same 300ms debounce, same `guard key == query` after
// every await — with two additions the Library has no need for:
//
//   • `addedSlugs` / `addingSlug`, the per-row add lifecycle. The sheet adds
//     one exercise at a time and must keep showing "In library" for a row the
//     user already tapped, even as later pages stream in.
//   • `didAddAny`, so the host knows whether to invalidate the Library's own
//     page cache on dismiss. Adding nothing must not cost a refetch.
@MainActor
@Observable
final class ExerciseCatalogViewModel {
  struct PageState {
    var items: [CatalogExercise]
    var total: Int
    var canLoadMore: Bool
  }

  // Inputs (driven by the view).
  var searchText = ""
  var category: String?
  var muscle: String?

  // Outputs.
  private(set) var exercises: [CatalogExercise] = []
  private(set) var total = 0
  private(set) var isLoading = false
  private(set) var isLoadingMore = false
  private(set) var hasLoadedOnce = false
  var error: PresentableError?

  /// Slugs added during this sheet's lifetime, including ones the server
  /// reported as already present. Unioned with each row's server-side
  /// `inLibrary` so a row never flips back to "Add" after a reload.
  private(set) var addedSlugs: Set<String> = []
  /// The row with an add in flight — at most one; the rows are plain buttons,
  /// not AsyncButtons, so the spinner state lives here.
  private(set) var addingSlug: String?
  /// True once any add succeeded, so the host only refreshes when it must.
  private(set) var didAddAny = false

  private var nextOffset = 0
  private var canLoadMore = false
  private var cache = PageCache<ExerciseCatalogQuery, PageState>()
  private var debounceTask: Task<Void, Never>?

  private let pageSize = 30

  // MARK: - Derived

  var query: ExerciseCatalogQuery {
    ExerciseCatalogQuery(search: trimmedSearch, category: category, muscle: muscle)
  }

  private var trimmedSearch: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var isEmpty: Bool { hasLoadedOnce && !isLoading && exercises.isEmpty }
  var showSkeleton: Bool { !hasLoadedOnce && isLoading }
  var hasFilters: Bool { category != nil || muscle != nil }

  func isInLibrary(_ exercise: CatalogExercise) -> Bool {
    addedSlugs.contains(exercise.slug) || (exercise.inLibrary ?? false)
  }

  // MARK: - Lifecycle

  func start() async {
    guard !hasLoadedOnce else { return }
    await reload()
  }

  /// Debounced reload for search-text changes (~300ms), matching the Library.
  func searchTextChanged() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      await self?.reload()
    }
  }

  func clearFilters() {
    category = nil
    muscle = nil
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

  /// Force a network refresh of the current query (pull-to-refresh / retry).
  func refresh() async {
    cache.invalidate(query)
    await fetchFirstPage(key: query)
  }

  func loadMore() async {
    guard canLoadMore, !isLoadingMore, !isLoading else { return }
    let key = query
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let state = try await fetch(query: key, offset: nextOffset, existing: exercises)
      guard key == query else { return }
      apply(state)
      cache.store(state, for: key)
    } catch {
      guard key == query else { return }
      self.error = PresentableError.presentable(error)
    }
  }

  // MARK: - Adding

  /// Copy one exercise into the curated workout catalog. `created: false` (it
  /// was already there) is a success, not an error — both end in the same
  /// "In library" state, which is why nothing here branches on it.
  func add(_ exercise: CatalogExercise) async {
    guard addingSlug == nil, !isInLibrary(exercise) else { return }
    addingSlug = exercise.slug
    defer { addingSlug = nil }
    do {
      _ = try await FuelAPI.addCatalogExercise(slug: exercise.slug)
      addedSlugs.insert(exercise.slug)
      didAddAny = true
      // The catalog pages now carry a stale `inLibrary`; drop them so a later
      // reopen of this sheet reflects the add without relying on addedSlugs.
      cache.invalidate()
    } catch {
      self.error = PresentableError.presentable(error)
    }
  }

  // MARK: - Fetching

  private func fetchFirstPage(key: ExerciseCatalogQuery) async {
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

  private func fetch(
    query key: ExerciseCatalogQuery,
    offset: Int,
    existing: [CatalogExercise]
  ) async throws -> PageState {
    let (page, count) = try await FuelAPI.exerciseCatalog(
      search: key.search,
      category: key.category,
      muscle: key.muscle,
      limit: pageSize,
      offset: offset
    )
    let combined = existing + page
    return PageState(
      items: combined,
      total: count,
      canLoadMore: combined.count < count && !page.isEmpty
    )
  }

  private func apply(_ state: PageState) {
    exercises = state.items
    total = state.total
    nextOffset = state.items.count
    canLoadMore = state.canLoadMore
    error = nil
  }
}

// The dataset's own vocabularies, verbatim — these are the values the backend
// matches with `eq`, so they are lowercase dataset spellings, not display
// copy. Title-casing for the chips happens at render time via
// `CatalogExercise.titleCased`.
//
// Both lists are closed sets today; a value a future dataset release adds
// simply won't have a chip (the exercises still appear under "All"), which is
// why nothing downstream switches exhaustively over them.
enum ExerciseCatalogFilters {
  static let categories = [
    "strength",
    "stretching",
    "plyometrics",
    "powerlifting",
    "olympic weightlifting",
    "strongman",
    "cardio",
  ]

  /// Ordered head-to-toe rather than alphabetically — you pick a muscle by
  /// where it is on the body, not by its initial.
  static let muscles = [
    "chest",
    "shoulders",
    "triceps",
    "biceps",
    "forearms",
    "lats",
    "middle back",
    "lower back",
    "traps",
    "neck",
    "abdominals",
    "glutes",
    "quadriceps",
    "hamstrings",
    "calves",
    "adductors",
    "abductors",
  ]
}
