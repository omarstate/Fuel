import Testing
import Foundation
@testable import Fuel

// Hand-computed against frontend/src/app-editorial/use-streaks.ts:
// 180-day window, ±10% goal band, today-in-progress falls back to yesterday.
@Suite("Streaks")
struct StreaksTests {
  private let cal = TestCal.utc
  private let today = TestCal.date(2026, 7, 19)

  // Build a dayKey n days before today.
  private func key(daysAgo n: Int) -> String {
    DayBounds.dayKey(DayBounds.addDays(today, -n, calendar: cal), calendar: cal)
  }

  private func compute(_ perDay: [String: Int], goal: Int = 2000) -> Streaks.Result {
    Streaks.compute(perDayCalories: perDay, goalCalories: goal, today: today, calendar: cal)
  }

  @Test("consecutive logged days from today")
  func consecutive() {
    let perDay = [key(daysAgo: 0): 1500, key(daysAgo: 1): 1200, key(daysAgo: 2): 900]
    #expect(compute(perDay).logging == 3)
  }

  @Test("a gap breaks the run")
  func gapBreaks() {
    // today + 2 days ago logged, but yesterday missing → only today counts.
    let perDay = [key(daysAgo: 0): 1500, key(daysAgo: 2): 900]
    #expect(compute(perDay).logging == 1)
  }

  @Test("today not logged falls back to yesterday")
  func todayFallback() {
    let perDay = [key(daysAgo: 1): 1500, key(daysAgo: 2): 1400, key(daysAgo: 3): 1300]
    #expect(compute(perDay).logging == 3)
  }

  @Test("neither today nor yesterday → zero")
  func brokenStreak() {
    let perDay = [key(daysAgo: 2): 1500, key(daysAgo: 3): 1400]
    #expect(compute(perDay).logging == 0)
  }

  @Test("goal band ±10% and in-progress today falls back for the goal streak")
  func goalBand() {
    // goal 2000 → band ±200 → [1800, 2200].
    let perDay = [
      key(daysAgo: 0): 500,   // logged, but below the goal band (in-progress today)
      key(daysAgo: 1): 1850,  // within band
      key(daysAgo: 2): 2200,  // 200 diff — inclusive edge, within band
      key(daysAgo: 3): 2300,  // 300 diff — outside band, breaks goal streak
    ]
    let r = compute(perDay)
    #expect(r.logging == 4)       // all four days have a meal
    #expect(r.goal == 2)          // today skipped (in-progress) → 1 day ago + 2 days ago, then 3 breaks
  }

  @Test("goal band exclusive just past 10%")
  func goalBandExclusive() {
    // 2201 is 201 off a 2000 goal → outside the ±200 band.
    let perDay = [key(daysAgo: 0): 2201]
    #expect(compute(perDay).goal == 0)
    #expect(compute(perDay).logging == 1)
  }

  @Test("empty history is zero/zero")
  func empty() {
    #expect(compute([:]) == Streaks.Result.zero)
  }
}
