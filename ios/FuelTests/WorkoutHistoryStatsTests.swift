import Testing
import Foundation
@testable import Fuel

// Hand-computed against the header stats in
// frontend/src/app-editorial/workouts-home.tsx. "This week" is a ROLLING
// 7×24h window (the web's WEEK_MS), not a calendar week — the boundary cases
// below are the point of the test. `relativeDay` diverges deliberately: we
// bucket by local calendar day, so the label flips at midnight.
@Suite("Workout history stats")
struct WorkoutHistoryStatsTests {
  private let cal = TestCal.utc
  private let now = TestCal.date(2026, 7, 19, 12, 0)

  private func hoursAgo(_ h: Double) -> Date {
    now.addingTimeInterval(-h * 3600)
  }

  private func session(startedAt: Date) -> HistorySession {
    HistorySession(
      session: WorkoutSession(userId: UUID(), status: .completed, startedAt: startedAt),
      exerciseCount: 3,
      setCount: 9
    )
  }

  // MARK: - sessionsThisWeek

  @Test("the rolling window includes 6d23h and excludes 7d1h")
  func rollingWeekBoundary() {
    let dates = [
      hoursAgo(6 * 24 + 23),  // 6d23h ago — inside
      hoursAgo(7 * 24 + 1),   // 7d01h ago — outside
    ]
    #expect(WorkoutHistoryStats.sessionsThisWeek(startedAt: dates, now: now) == 1)
  }

  @Test("exactly 7×24h ago is still inside the window")
  func rollingWeekExactEdge() {
    #expect(WorkoutHistoryStats.sessionsThisWeek(startedAt: [hoursAgo(7 * 24)], now: now) == 1)
  }

  @Test("counting a mixed history")
  func rollingWeekMixed() {
    let dates = [hoursAgo(1), hoursAgo(30), hoursAgo(100), hoursAgo(200), hoursAgo(400)]
    // 400h ≈ 16.7 days and 200h ≈ 8.3 days are out; the other three are in.
    #expect(WorkoutHistoryStats.sessionsThisWeek(startedAt: dates, now: now) == 3)
  }

  @Test("no sessions counts zero")
  func rollingWeekEmpty() {
    #expect(WorkoutHistoryStats.sessionsThisWeek([], now: now) == 0)
  }

  @Test("the HistorySession overload reads startedAt off each row")
  func rollingWeekFromSessions() {
    let sessions = [session(startedAt: hoursAgo(2)), session(startedAt: hoursAgo(300))]
    #expect(WorkoutHistoryStats.sessionsThisWeek(sessions, now: now) == 1)
  }

  // MARK: - relativeDay

  @Test("today and yesterday bucket by local calendar day")
  func relativeDayRecent() {
    #expect(WorkoutHistoryStats.relativeDay(now, now: now, calendar: cal) == .today)
    // 06:00 the same morning is still today, 8 hours back or not.
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 19, 6, 0), now: now, calendar: cal) == .today
    )
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 18, 23, 0), now: now, calendar: cal) == .yesterday
    )
  }

  @Test("crossing local midnight flips the label even when only hours have passed")
  func relativeDayMidnightBoundary() {
    let justAfterMidnight = TestCal.date(2026, 7, 19, 1, 0)
    let lateLastNight = TestCal.date(2026, 7, 18, 23, 0)
    // Two hours apart, but a calendar day apart — the web's raw-ms port would
    // call this "today"; we say "yesterday".
    #expect(
      WorkoutHistoryStats.relativeDay(lateLastNight, now: justAfterMidnight, calendar: cal) == .yesterday
    )
  }

  @Test("three days back reports daysAgo")
  func relativeDayDays() {
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 16, 9, 0), now: now, calendar: cal) == .daysAgo(3)
    )
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 14, 9, 0), now: now, calendar: cal) == .daysAgo(5)
    )
  }

  @Test("seven days and beyond report whole weeks")
  func relativeDayWeeks() {
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 12, 9, 0), now: now, calendar: cal) == .weeksAgo(1)
    )
    // 2026-07-05 is 14 days back → 2 weeks.
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 5, 9, 0), now: now, calendar: cal) == .weeksAgo(2)
    )
    // 13 days back still rounds down to 1 week.
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 6, 9, 0), now: now, calendar: cal) == .weeksAgo(1)
    )
  }

  @Test("a future date never reads as negative")
  func relativeDayFuture() {
    #expect(
      WorkoutHistoryStats.relativeDay(TestCal.date(2026, 7, 20, 9, 0), now: now, calendar: cal) == .today
    )
  }

  // MARK: - lastSession

  @Test("lastSession picks the newest regardless of array order")
  func lastSession() {
    let newest = hoursAgo(2)
    let sessions = [
      session(startedAt: hoursAgo(100)),
      session(startedAt: newest),
      session(startedAt: hoursAgo(50)),
    ]
    #expect(WorkoutHistoryStats.lastSession(sessions)?.startedAt == newest)
  }

  @Test("lastSession of an empty history is nil")
  func lastSessionEmpty() {
    #expect(WorkoutHistoryStats.lastSession([]) == nil)
  }
}
