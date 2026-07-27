import Foundation

// PURE Foundation port of frontend/src/app-editorial/use-week-meals.ts plus the
// summary math in week-chart.tsx. Builds the current (Monday-first) local week
// of per-day calorie totals, and turns the week's net-vs-goal delta into a
// direction-aware one-line read (projected kg via KCAL_PER_KG = 7700).

// One calendar day in the current week. `logged` distinguishes a day with no
// meals at all from a day the user genuinely ate very little — so the chart can
// render "not logged" differently from a real deficit, and the weekly stats can
// exclude untracked days instead of counting them as zeros.
struct WeekDay: Equatable, Sendable, Identifiable {
  /// Local YYYY-MM-DD key.
  let key: String
  /// Mon-first index 0..6.
  let index: Int
  /// Sum of calories logged that day.
  var calories: Int
  /// True once at least one meal exists for the day.
  var logged: Bool
  var isToday: Bool
  var isFuture: Bool

  var id: Int { index }
}

struct WeekSummary: Equatable, Sendable {
  let hasData: Bool
  let daysOnTarget: Int
  let trackedCount: Int
  let dailyAverage: Int
  /// Net calories vs goal across tracked days (positive = surplus).
  let net: Int
  /// True when the net trend matches the user's goal direction.
  let onTrack: Bool
  /// One-line, direction-aware summary text (English; matches lib/i18n/en.ts).
  let text: String
}

enum WeekAggregation {
  /// A day counts as "on target" if within this fraction of the goal.
  static let targetBand = 0.1

  enum Outcome: Sendable, Equatable { case under, onTarget, over }

  /// Monday (local midnight) of the week containing `date`.
  static func startOfWeek(_ date: Date, calendar: Calendar = .current) -> Date {
    let d = DayBounds.startOfDay(date, calendar: calendar)
    return DayBounds.addDays(d, -mondayIndex(d, calendar: calendar), calendar: calendar)
  }

  /// Mon-first index (0 = Monday … 6 = Sunday) for `date`.
  /// JS `(getDay()+6)%7` where getDay is 0=Sun; Swift weekday is 1=Sun…7=Sat,
  /// so getDay == weekday-1 and the expression becomes `(weekday+5)%7`.
  static func mondayIndex(_ date: Date, calendar: Calendar = .current) -> Int {
    (calendar.component(.weekday, from: date) + 5) % 7
  }

  /// The seven Mon–Sun days of the current local week.
  /// - Parameter perDayCalories: local dayKey → summed calories (a present key
  ///   means the day was logged, even if it sums to 0).
  static func buildWeek(
    perDayCalories: [String: Int],
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> [WeekDay] {
    let weekStart = startOfWeek(now, calendar: calendar)
    let todayIdx = mondayIndex(now, calendar: calendar)
    return (0..<7).map { i in
      let key = DayBounds.dayKey(DayBounds.addDays(weekStart, i, calendar: calendar), calendar: calendar)
      let cals = perDayCalories[key]
      return WeekDay(
        key: key,
        index: i,
        calories: cals ?? 0,
        logged: cals != nil,
        isToday: i == todayIdx,
        isFuture: i > todayIdx
      )
    }
  }

  static func outcome(calories: Int, goal: Int) -> Outcome {
    if Double(calories) > Double(goal) * (1 + targetBand) { return .over }
    if Double(calories) < Double(goal) * (1 - targetBand) { return .under }
    return .onTarget
  }

  /// Weekly scoreboard + direction-aware net summary over the tracked days.
  static func summary(days: [WeekDay], goal: Int, direction: Direction) -> WeekSummary {
    let tracked = days.filter { $0.logged && !$0.isFuture }
    let hasData = !tracked.isEmpty
    let daysOnTarget = tracked.filter { outcome(calories: $0.calories, goal: goal) == .onTarget }.count
    let avg = hasData
      ? Int((Double(tracked.reduce(0) { $0 + $1.calories }) / Double(tracked.count)).rounded())
      : 0
    let net = tracked.reduce(0) { $0 + ($1.calories - goal) }
    let (onTrack, text) = netText(net: net, direction: direction)
    return WeekSummary(
      hasData: hasData,
      daysOnTarget: daysOnTarget,
      trackedCount: tracked.count,
      dailyAverage: avg,
      net: net,
      onTrack: onTrack,
      text: text
    )
  }

  // Port of `netSummary` in week-chart.tsx. Copy matches lib/i18n/en.ts.
  private static func netText(net: Int, direction: Direction) -> (Bool, String) {
    let kg = abs(Double(net)) / TargetMath.kcalPerKg
    let kgLabel = kg < 0.1
      ? "under 0.1 kg"
      : String(format: "≈%.1f kg", kg)

    switch direction {
    case .maintain:
      let onTrack = abs(Double(net)) < TargetMath.kcalPerKg * 0.15
      if onTrack { return (true, "Holding steady") }
      let phrase = net < 0 ? "Under maintenance" : "Over maintenance"
      return (false, "\(phrase) · \(kgLabel)")
    case .cut:
      if net < 0 { return (true, "On track to lose \(kgLabel)") }
      return (false, "Surplus this week · \(kgLabel) against your cut")
    case .bulk:
      if net > 0 { return (true, "On track to gain \(kgLabel)") }
      return (false, "Deficit this week · \(kgLabel) against your bulk")
    }
  }
}
