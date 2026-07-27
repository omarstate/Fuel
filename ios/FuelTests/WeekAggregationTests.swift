import Testing
import Foundation
@testable import Fuel

// Hand-computed against use-week-meals.ts + week-chart.tsx.
@Suite("Week aggregation")
struct WeekAggregationTests {
  private let cal = TestCal.utc

  @Test("Monday is index 0, week start is a Monday")
  func mondayFirst() {
    // 2026-07-19 is a Sunday → mondayIndex 6.
    #expect(WeekAggregation.mondayIndex(TestCal.date(2026, 7, 19), calendar: cal) == 6)
    // 2026-07-13 is a Monday → index 0.
    #expect(WeekAggregation.mondayIndex(TestCal.date(2026, 7, 13), calendar: cal) == 0)
    // Start of the week containing any date is always a Monday (index 0).
    let start = WeekAggregation.startOfWeek(TestCal.date(2026, 7, 19), calendar: cal)
    #expect(WeekAggregation.mondayIndex(start, calendar: cal) == 0)
    #expect(DayBounds.dayKey(start, calendar: cal) == "2026-07-13")
  }

  @Test("buildWeek: indices ascending, today flagged, future flagged")
  func buildWeek() {
    let now = TestCal.date(2026, 7, 15, 12) // Wednesday → todayIdx 2
    let days = WeekAggregation.buildWeek(perDayCalories: [:], now: now, calendar: cal)
    #expect(days.count == 7)
    #expect(days.map(\.index) == Array(0..<7))
    #expect(days.first?.key == "2026-07-13")
    #expect(days[2].isToday == true)
    #expect(days[3].isFuture == true)
    #expect(days[1].isFuture == false)
  }

  @Test("a logged zero-calorie day is distinct from an un-logged day")
  func loggedVsZero() {
    let now = TestCal.date(2026, 7, 15, 12)
    let monKey = "2026-07-13"
    let days = WeekAggregation.buildWeek(perDayCalories: [monKey: 0], now: now, calendar: cal)
    #expect(days[0].logged == true)   // present in map → logged, even at 0 kcal
    #expect(days[0].calories == 0)
    #expect(days[1].logged == false)  // absent → not logged
  }

  // Direct WeekDay construction so summary math is independent of dates.
  private func day(_ index: Int, _ cals: Int, logged: Bool = true, future: Bool = false) -> WeekDay {
    WeekDay(key: "k\(index)", index: index, calories: cals, logged: logged, isToday: false, isFuture: future)
  }

  @Test("maintain: net within 15% of a kg holds steady")
  func maintainSteady() {
    let days = [day(0, 2000), day(1, 2000)] // net 0
    let s = WeekAggregation.summary(days: days, goal: 2000, direction: .maintain)
    #expect(s.net == 0)
    #expect(s.onTrack == true)
    #expect(s.text == "Holding steady")
    #expect(s.trackedCount == 2)
    #expect(s.daysOnTarget == 2)
  }

  @Test("cut: a deficit is on track and projects kg lost")
  func cutOnTrack() {
    // two days 1000 under a 2000 goal → net -2000 → 2000/7700 ≈ 0.3 kg.
    let days = [day(0, 1000), day(1, 1000)]
    let s = WeekAggregation.summary(days: days, goal: 2000, direction: .cut)
    #expect(s.net == -2000)
    #expect(s.onTrack == true)
    #expect(s.text == "On track to lose ≈0.3 kg")
  }

  @Test("cut: a surplus is off track")
  func cutSurplus() {
    let days = [day(0, 3000), day(1, 3000)] // net +2000
    let s = WeekAggregation.summary(days: days, goal: 2000, direction: .cut)
    #expect(s.net == 2000)
    #expect(s.onTrack == false)
    #expect(s.text == "Surplus this week · ≈0.3 kg against your cut")
  }

  @Test("future and un-logged days are excluded from the summary")
  func excludesUntracked() {
    let days = [day(0, 2000), day(1, 0, logged: false), day(2, 5000, future: true)]
    let s = WeekAggregation.summary(days: days, goal: 2000, direction: .maintain)
    #expect(s.trackedCount == 1)
    #expect(s.dailyAverage == 2000)
  }

  @Test("outcome banding at ±10%")
  func outcome() {
    #expect(WeekAggregation.outcome(calories: 2200, goal: 2000) == .onTarget)
    #expect(WeekAggregation.outcome(calories: 2201, goal: 2000) == .over)
    #expect(WeekAggregation.outcome(calories: 1800, goal: 2000) == .onTarget)
    #expect(WeekAggregation.outcome(calories: 1799, goal: 2000) == .under)
  }
}
