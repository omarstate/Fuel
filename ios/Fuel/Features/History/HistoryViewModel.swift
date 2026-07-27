import Foundation
import Observation

// Drives History: the last 30 days of logs, grouped by local calendar day
// (most recent first). One fetch, grouped client-side with DayBounds; same
// optimistic swipe-to-delete pattern as Today, with a snapshot rollback.
@MainActor
@Observable
final class HistoryViewModel {
  private let repo = MealLogRepository()

  private(set) var days: [DayGroup] = []
  /// Local dayKey → summed calories over the streak window (for the overview).
  private(set) var perDayCalories: [String: Int] = [:]
  private(set) var hasLoadedOnce = false
  private(set) var isRefreshing = false
  var error: PresentableError?

  /// Targets + goal direction, set by the view from AppState (drives the overview).
  var targets: Targets = TargetMath.defaultTargets
  var direction: Direction = .maintain

  struct DayGroup: Identifiable, Equatable {
    let key: String
    /// Local start-of-day, for the header label.
    let date: Date
    let meals: [LoggedMeal]

    var id: String { key }
    var totals: LoggedMeal.Totals { meals.totals }

    /// The day's meals split into Breakfast/Lunch/Dinner/Snack buckets, in that
    /// canonical order, skipping any type with nothing logged.
    var byType: [(type: MealType, meals: [LoggedMeal])] {
      MealType.allCases.compactMap { type in
        let items = meals.filter { $0.mealType == type }
        return items.isEmpty ? nil : (type, items)
      }
    }
  }

  var isEmpty: Bool { days.isEmpty }

  // MARK: - 30-day series + stats (the History hero)

  /// One entry per calendar day for the last 30 days, oldest → newest, with
  /// calories + protein looked up from the grouped logs (0 for un-logged days).
  struct HistoryDay: Identifiable, Equatable {
    let date: Date
    let key: String
    let calories: Int
    let protein: Int
    let isToday: Bool
    var logged: Bool { calories > 0 || protein > 0 }
    var id: String { key }
  }

  var last30: [HistoryDay] {
    var kcalByDay: [String: Int] = [:]
    var proByDay: [String: Int] = [:]
    for group in days {
      kcalByDay[group.key] = group.totals.calories
      proByDay[group.key] = group.totals.protein
    }
    let today = DayBounds.startOfDay(Date())
    return (0..<30).reversed().map { offset in
      let date = DayBounds.addDays(today, -offset)
      let key = DayBounds.dayKey(date)
      return HistoryDay(
        date: date, key: key,
        calories: kcalByDay[key] ?? 0,
        protein: proByDay[key] ?? 0,
        isToday: offset == 0
      )
    }
  }

  private var loggedDays: [HistoryDay] { last30.filter(\.logged) }
  var daysLoggedCount: Int { loggedDays.count }
  var totalMeals: Int { days.reduce(0) { $0 + $1.meals.count } }
  var avgCalories: Int {
    loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.calories } / loggedDays.count
  }
  var avgProtein: Int {
    loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.protein } / loggedDays.count
  }

  // MARK: - Overview (top of the tab)

  /// Today's macro totals, taken from the most recent day group when it's today.
  var todayTotals: LoggedMeal.Totals {
    guard let first = days.first,
          Calendar.current.isDateInToday(first.date) else { return LoggedMeal.Totals() }
    return first.totals
  }

  var consumed: Int { todayTotals.calories }
  var proteinLeft: Int { max(targets.protein - todayTotals.protein, 0) }

  /// Server per-day totals with today patched from the live grouped meals, so the
  /// overview ring / streaks / chart stay coherent after an optimistic delete.
  private var patchedPerDay: [String: Int] {
    var p = perDayCalories
    let todayKey = DayBounds.dayKey(Date())
    if consumed > 0 { p[todayKey] = consumed } else { p.removeValue(forKey: todayKey) }
    return p
  }

  var weekDays: [WeekDay] { WeekAggregation.buildWeek(perDayCalories: patchedPerDay) }
  var weekSummary: WeekSummary {
    WeekAggregation.summary(days: weekDays, goal: targets.calories, direction: direction)
  }
  var streaks: Streaks.Result {
    Streaks.compute(perDayCalories: patchedPerDay, goalCalories: targets.calories)
  }

  func updateContext(targets: Targets, direction: Direction) {
    self.targets = targets
    self.direction = direction
  }

  func initialLoad(targets: Targets, direction: Direction) async {
    self.targets = targets
    self.direction = direction
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
      async let recent = repo.recentMeals(days: 30)
      async let totals = repo.dailyCalorieTotals()
      let (meals, perDay) = try await (recent, totals)
      days = Self.group(meals)
      perDayCalories = perDay
      error = nil
    } catch {
      self.error = PresentableError(error)
    }
  }

  func delete(_ meal: LoggedMeal) async {
    let snapshot = days
    days = Self.removing(meal, from: days)
    do {
      try await repo.delete(id: meal.id)
    } catch {
      days = snapshot
      self.error = PresentableError(error)
    }
  }

  // MARK: - Grouping

  /// Groups newest-first meals into day buckets, preserving encounter order (so
  /// groups stay most-recent-first and rows within a day stay newest-first).
  private static func group(_ meals: [LoggedMeal], calendar: Calendar = .current) -> [DayGroup] {
    var order: [String] = []
    var buckets: [String: [LoggedMeal]] = [:]
    for meal in meals {
      let key = DayBounds.dayKey(meal.loggedAt, calendar: calendar)
      if buckets[key] == nil {
        order.append(key)
        buckets[key] = []
      }
      buckets[key]?.append(meal)
    }
    return order.map { key in
      let items = buckets[key] ?? []
      let date = items.first.map { DayBounds.startOfDay($0.loggedAt, calendar: calendar) } ?? Date()
      return DayGroup(key: key, date: date, meals: items)
    }
  }

  private static func removing(_ meal: LoggedMeal, from days: [DayGroup]) -> [DayGroup] {
    days.compactMap { group in
      guard group.meals.contains(where: { $0.id == meal.id }) else { return group }
      let remaining = group.meals.filter { $0.id != meal.id }
      return remaining.isEmpty ? nil : DayGroup(key: group.key, date: group.date, meals: remaining)
    }
  }
}
