import Foundation

// PURE Foundation port of the header stats on
// frontend/src/app-editorial/workouts-home.tsx — the "this week" count, the
// "last session" recency label and the pick of the newest session.
enum WorkoutHistoryStats {
  /// The web's `WEEK_MS`: a rolling 7×24h window, NOT a calendar week.
  static let weekInterval: TimeInterval = 7 * 24 * 60 * 60

  /// How many of `dates` fall inside the last 7×24 hours. Takes bare dates so
  /// the rule is testable without building whole sessions.
  static func sessionsThisWeek(startedAt dates: some Sequence<Date>, now: Date) -> Int {
    let cutoff = now.addingTimeInterval(-weekInterval)
    return dates.filter { $0 >= cutoff }.count
  }

  /// Convenience over the history list.
  static func sessionsThisWeek(_ sessions: [HistorySession], now: Date) -> Int {
    sessionsThisWeek(startedAt: sessions.map(\.startedAt), now: now)
  }

  /// How long ago a session was, bucketed. The view localizes it — this stays
  /// free of user-facing strings so it can be unit-tested.
  enum RelativeDay: Equatable, Sendable {
    case today
    case yesterday
    case daysAgo(Int)
    case weeksAgo(Int)
  }

  /// Buckets `date` against `now` using the same thresholds as `relativeDay` in
  /// workouts-home.tsx (0 → today, 1 → yesterday, <7 → days, else whole weeks).
  ///
  /// Deliberate divergence: the web floors a raw millisecond difference, which
  /// calls 11pm-yesterday "today" when you look at it at 1am. We count local
  /// CALENDAR days instead, so the label flips at midnight like a reader expects.
  static func relativeDay(_ date: Date, now: Date, calendar: Calendar = .current) -> RelativeDay {
    let then = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: now)
    let diffDays = calendar.dateComponents([.day], from: then, to: today).day ?? 0
    if diffDays <= 0 { return .today }
    if diffDays == 1 { return .yesterday }
    if diffDays < 7 { return .daysAgo(diffDays) }
    return .weeksAgo(diffDays / 7)
  }

  /// The most recent session. The repository already orders newest-first, but
  /// the view shouldn't have to depend on that.
  static func lastSession(_ sessions: [HistorySession]) -> HistorySession? {
    sessions.max { $0.startedAt < $1.startedAt }
  }
}
