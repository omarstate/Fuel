import Foundation
import Observation

// Drives the Today screen. Instant-render pattern: keeps the last data on screen
// while a refresh runs, so only the very first load shows a skeleton. Today's
// meals are the source of truth for the ring/macros; the 180-day daily totals
// feed streaks and the week chart, with today's bar/streak patched live from the
// local meals so optimistic edits reflect immediately.
@MainActor
@Observable
final class TodayViewModel {
  private let repo = MealLogRepository()

  private(set) var meals: [LoggedMeal] = []
  /// Local dayKey → summed calories over the streak window (server snapshot).
  private(set) var perDayCalories: [String: Int] = [:]

  private(set) var hasLoadedOnce = false
  private(set) var isRefreshing = false
  var error: PresentableError?

  /// Targets + goal direction, set by the view from AppState on load.
  var targets: Targets = TargetMath.defaultTargets
  var direction: Direction = .maintain

  // MARK: - Derived

  var totals: LoggedMeal.Totals { meals.totals }
  var consumed: Int { totals.calories }
  var remaining: Int { max(targets.calories - consumed, 0) }
  var pace: PaceReading { CaloriePace.compute(consumed: consumed, goal: targets.calories) }

  var weekDays: [WeekDay] {
    WeekAggregation.buildWeek(perDayCalories: patchedPerDay)
  }
  var weekSummary: WeekSummary {
    WeekAggregation.summary(days: weekDays, goal: targets.calories, direction: direction)
  }
  var streaks: Streaks.Result {
    Streaks.compute(perDayCalories: patchedPerDay, goalCalories: targets.calories)
  }

  /// Server per-day totals with today's entry replaced by the live local total,
  /// so the ring, chart and streak stay coherent after optimistic add/delete.
  private var patchedPerDay: [String: Int] {
    var p = perDayCalories
    let todayKey = DayBounds.dayKey(Date())
    if meals.isEmpty {
      p.removeValue(forKey: todayKey)
    } else {
      p[todayKey] = consumed
    }
    return p
  }

  /// All four sections in MEAL_TYPE_ORDER, always present (empty ones render a
  /// "Nothing logged yet" row with an inline add), matching the web log.
  var sections: [(type: MealType, meals: [LoggedMeal])] {
    MealTypeSuggestion.order.map { type in
      (type, meals.filter { $0.mealType == type })
    }
  }

  var isEmpty: Bool { meals.isEmpty }

  // MARK: - Loading

  /// First load — shows a skeleton only if nothing has ever loaded.
  func initialLoad(targets: Targets, direction: Direction) async {
    self.targets = targets
    self.direction = direction
    guard !hasLoadedOnce else { return }
    await refresh()
  }

  func updateContext(targets: Targets, direction: Direction) {
    self.targets = targets
    self.direction = direction
  }

  func refresh() async {
    isRefreshing = true
    defer {
      isRefreshing = false
      hasLoadedOnce = true
    }
    do {
      async let todayMeals = repo.meals(on: Date())
      async let totals = repo.dailyCalorieTotals()
      let (m, p) = try await (todayMeals, totals)
      self.meals = m
      self.perDayCalories = p
      self.error = nil
    } catch {
      self.error = PresentableError(error)
    }
  }

  // MARK: - Mutations

  /// Build + insert a meal for the signed-in user (optimistic; rolls back on
  /// failure by rethrowing so the sheet stays open).
  func log(_ new: ManualAddSheet.NewMeal) async throws {
    let userID = try await repo.userID()
    let meal = LoggedMeal(
      userId: userID,
      name: new.name,
      mealType: new.mealType,
      servingSize: new.servingSize,
      calories: new.calories,
      protein: new.protein,
      carbs: new.carbs,
      fat: new.fat,
      loggedAt: Date()
    )
    meals.insert(meal, at: 0) // newest first, matches logged_at desc
    do {
      try await repo.insert(meal)
    } catch {
      meals.removeAll { $0.id == meal.id }
      throw error
    }
  }

  /// Optimistic delete: drop locally, delete in the DB, restore + surface an
  /// error banner on failure.
  func delete(_ meal: LoggedMeal) async {
    guard let index = meals.firstIndex(where: { $0.id == meal.id }) else { return }
    meals.remove(at: index)
    do {
      try await repo.delete(id: meal.id)
    } catch {
      meals.insert(meal, at: min(index, meals.count))
      self.error = PresentableError(error)
    }
  }
}
