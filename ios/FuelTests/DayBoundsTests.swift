import Testing
import Foundation
@testable import Fuel

// Hand-computed against frontend/src/app-editorial/day-bounds.ts.
@Suite("DayBounds")
struct DayBoundsTests {
  private let cal = TestCal.utc

  @Test("dayKey format and stability across a day")
  func dayKeyStable() {
    let midnight = TestCal.date(2026, 7, 19, 0, 0)
    let lateNight = TestCal.date(2026, 7, 19, 23, 59)
    #expect(DayBounds.dayKey(midnight, calendar: cal) == "2026-07-19")
    #expect(DayBounds.dayKey(lateNight, calendar: cal) == "2026-07-19")
    // Single-digit month/day zero-pad.
    #expect(DayBounds.dayKey(TestCal.date(2026, 1, 5), calendar: cal) == "2026-01-05")
  }

  @Test("startOfDay drops the time")
  func startOfDay() {
    let d = TestCal.date(2026, 7, 19, 14, 30)
    let start = DayBounds.startOfDay(d, calendar: cal)
    let comps = cal.dateComponents([.hour, .minute, .second], from: start)
    #expect(comps.hour == 0 && comps.minute == 0 && comps.second == 0)
    #expect(DayBounds.dayKey(start, calendar: cal) == "2026-07-19")
  }

  @Test("addDays crosses month and year boundaries")
  func addDays() {
    #expect(DayBounds.dayKey(DayBounds.addDays(TestCal.date(2026, 7, 31), 1, calendar: cal), calendar: cal) == "2026-08-01")
    #expect(DayBounds.dayKey(DayBounds.addDays(TestCal.date(2026, 12, 31), 1, calendar: cal), calendar: cal) == "2027-01-01")
    #expect(DayBounds.dayKey(DayBounds.addDays(TestCal.date(2026, 3, 1), -1, calendar: cal), calendar: cal) == "2026-02-28")
  }

  @Test("interval until next midnight")
  func untilMidnight() {
    // 23:00 → one hour to midnight.
    let at23 = TestCal.date(2026, 7, 19, 23, 0)
    #expect(DayBounds.intervalUntilNextMidnight(from: at23, calendar: cal) == 3600)
    // exact midnight → a full day to the next one.
    let atMidnight = TestCal.date(2026, 7, 19, 0, 0)
    #expect(DayBounds.intervalUntilNextMidnight(from: atMidnight, calendar: cal) == 86400)
  }
}
