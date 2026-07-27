import Testing
import Foundation
@testable import Fuel

// Hand-computed against frontend/src/app-editorial/pace.ts.
// goal 2000 → tolerance 0.08 → tol band = 160 kcal.
@Suite("Pace")
struct PaceTests {
  private let cal = TestCal.utc

  @Test("over goal is checked first, regardless of time of day")
  func overFirst() {
    // Early morning (hour 8) but already past goal → over, not on/behind.
    let r = CaloriePace.compute(consumed: 2100, goal: 2000, now: TestCal.date(2026, 7, 19, 8), calendar: cal)
    #expect(r.status == .over)
    #expect(r.labelKey == .overGoal)
    #expect(r.remaining == -100)
  }

  @Test("wake-window start (hour 8): expected 0")
  func wakeStart() {
    // frac = 0, expected = 0, tol = 160.
    #expect(CaloriePace.compute(consumed: 160, goal: 2000, now: TestCal.date(2026, 7, 19, 8), calendar: cal).status == .on)
    #expect(CaloriePace.compute(consumed: 161, goal: 2000, now: TestCal.date(2026, 7, 19, 8), calendar: cal).status == .ahead)
    #expect(CaloriePace.compute(consumed: 0, goal: 2000, now: TestCal.date(2026, 7, 19, 8), calendar: cal).status == .on)
  }

  @Test("wake-window end (hour 22): expected == goal")
  func wakeEnd() {
    // frac = 1, expected = 2000, tol = 160.
    #expect(CaloriePace.compute(consumed: 1840, goal: 2000, now: TestCal.date(2026, 7, 19, 22), calendar: cal).status == .on)
    #expect(CaloriePace.compute(consumed: 1839, goal: 2000, now: TestCal.date(2026, 7, 19, 22), calendar: cal).status == .behind)
    #expect(CaloriePace.compute(consumed: 2000, goal: 2000, now: TestCal.date(2026, 7, 19, 22), calendar: cal).status == .on)
  }

  @Test("before wake clamps to 0, after wake clamps to 1")
  func clamping() {
    // hour 6 → frac clamps to 0 (expected 0).
    #expect(CaloriePace.compute(consumed: 50, goal: 2000, now: TestCal.date(2026, 7, 19, 6), calendar: cal).status == .on)
    // hour 23 → frac clamps to 1 (expected 2000) → well below → behind.
    #expect(CaloriePace.compute(consumed: 500, goal: 2000, now: TestCal.date(2026, 7, 19, 23), calendar: cal).status == .behind)
  }

  @Test("midday tolerance edges")
  func middayTolerance() {
    // hour 15 → frac = (15-8)/14 = 0.5 → expected 1000, tol 160 → band [840, 1160].
    let now = TestCal.date(2026, 7, 19, 15)
    #expect(CaloriePace.compute(consumed: 1000, goal: 2000, now: now, calendar: cal).status == .on)
    #expect(CaloriePace.compute(consumed: 1161, goal: 2000, now: now, calendar: cal).status == .ahead)
    #expect(CaloriePace.compute(consumed: 839, goal: 2000, now: now, calendar: cal).status == .behind)
    #expect(CaloriePace.compute(consumed: 1160, goal: 2000, now: now, calendar: cal).status == .on)
    #expect(CaloriePace.compute(consumed: 840, goal: 2000, now: now, calendar: cal).status == .on)
  }

  @Test("label text matches the web copy")
  func labels() {
    #expect(PaceLabelKey.onPace.text == "on pace")
    #expect(PaceLabelKey.aheadOfPace.text == "ahead of pace")
    #expect(PaceLabelKey.roomToSpare.text == "room to spare")
    #expect(PaceLabelKey.overGoal.text == "over goal")
  }
}
