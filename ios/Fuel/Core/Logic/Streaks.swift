import Foundation

// PURE Foundation port of the streak computation in
// frontend/src/app-editorial/use-streaks.ts (the pure part — the data fetch
// lives in MealLogRepository). Two streaks derived from per-day calorie totals:
//   - `logging`: consecutive local days with any meal logged (the habit streak).
//   - `goal`: consecutive days whose calories landed within ±10% of target.
// Today is only *required* to qualify once it's over — an in-progress day below
// goal keeps the streak alive via yesterday.
enum Streaks {
  /// How far back to look. A streak can't exceed this.
  static let historyDays = 180
  /// A day counts toward the goal streak if within this fraction of target.
  static let goalBand = 0.1

  struct Result: Equatable, Sendable {
    let logging: Int
    let goal: Int
    /// Longest goal-streak run anywhere in the history window ("best: N days").
    let bestGoal: Int

    init(logging: Int, goal: Int, bestGoal: Int = 0) {
      self.logging = logging
      self.goal = goal
      self.bestGoal = bestGoal
    }

    static let zero = Result(logging: 0, goal: 0, bestGoal: 0)
  }

  /// - Parameter perDayCalories: local dayKey ("yyyy-MM-dd") → summed calories.
  static func compute(
    perDayCalories: [String: Int],
    goalCalories: Int,
    today: Date = Date(),
    calendar: Calendar = .current
  ) -> Result {
    let loggedDays = Set(perDayCalories.keys)
    let band = Double(goalCalories) * goalBand
    let goalDays = Set(
      perDayCalories
        .filter { abs(Double($0.value - goalCalories)) <= band }
        .map(\.key)
    )
    return Result(
      logging: currentStreak(loggedDays, today: today, calendar: calendar),
      goal: currentStreak(goalDays, today: today, calendar: calendar),
      bestGoal: longestStreak(goalDays, today: today, calendar: calendar)
    )
  }

  /// Longest run of consecutive goal-qualifying days within the history window.
  private static func longestStreak(
    _ qualifies: Set<String>,
    today: Date,
    calendar: Calendar
  ) -> Int {
    var best = 0
    var run = 0
    for offset in 0...historyDays {
      let day = DayBounds.addDays(today, -offset, calendar: calendar)
      if qualifies.contains(DayBounds.dayKey(day, calendar: calendar)) {
        run += 1
        best = Swift.max(best, run)
      } else {
        run = 0
      }
    }
    return best
  }

  /// Length of the run of consecutive local days ending at today (or yesterday,
  /// so a not-yet-finished today doesn't break a live streak) for which the day
  /// key is in `qualifies`.
  private static func currentStreak(
    _ qualifies: Set<String>,
    today: Date,
    calendar: Calendar
  ) -> Int {
    var cursor = today
    if !qualifies.contains(DayBounds.dayKey(cursor, calendar: calendar)) {
      cursor = DayBounds.addDays(cursor, -1, calendar: calendar)
      if !qualifies.contains(DayBounds.dayKey(cursor, calendar: calendar)) { return 0 }
    }
    var n = 0
    while qualifies.contains(DayBounds.dayKey(cursor, calendar: calendar)) {
      n += 1
      cursor = DayBounds.addDays(cursor, -1, calendar: calendar)
    }
    return n
  }
}
