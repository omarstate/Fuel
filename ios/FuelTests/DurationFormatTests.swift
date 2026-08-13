import Testing
import Foundation
@testable import Fuel

// Hand-computed against the three TS formatters these port: `formatDuration`
// (session-timer.tsx), `fmtRest` (rest-timer.tsx) and `fmtWeight`
// (set-logger.tsx). The web ALWAYS shows the hour component on elapsed time, so
// the sub-hour cases below read "0:MM:SS" on purpose.
@Suite("Duration format")
struct DurationFormatTests {
  @Test("elapsed always renders H:MM:SS")
  func elapsed() {
    #expect(DurationFormat.elapsed(0) == "0:00:00")
    #expect(DurationFormat.elapsed(59) == "0:00:59")
    #expect(DurationFormat.elapsed(60) == "0:01:00")
    #expect(DurationFormat.elapsed(3599) == "0:59:59")
    #expect(DurationFormat.elapsed(3600) == "1:00:00")
    #expect(DurationFormat.elapsed(3661) == "1:01:01")
  }

  @Test("elapsed clamps a negative interval at zero")
  func elapsedClamps() {
    #expect(DurationFormat.elapsed(-30) == "0:00:00")
  }

  @Test("hours are not padded, so long sessions keep counting up")
  func elapsedLong() {
    #expect(DurationFormat.elapsed(36_000) == "10:00:00")
  }

  @Test("rest renders M:SS with unpadded minutes")
  func rest() {
    #expect(DurationFormat.rest(90) == "1:30")
    #expect(DurationFormat.rest(0) == "0:00")
    #expect(DurationFormat.rest(45) == "0:45")
    #expect(DurationFormat.rest(60) == "1:00")
    #expect(DurationFormat.rest(180) == "3:00")
    #expect(DurationFormat.rest(-5) == "0:00")
  }

  @Test("weight drops the decimal only when the value is whole")
  func weight() {
    #expect(DurationFormat.weight(80) == "80")
    #expect(DurationFormat.weight(82.5) == "82.5")
    #expect(DurationFormat.weight(62.50) == "62.5")
    #expect(DurationFormat.weight(0) == "0")
    #expect(DurationFormat.weight(12.34) == "12.3")
    #expect(DurationFormat.weight(12.36) == "12.4")
    #expect(DurationFormat.weight(140) == "140")
  }
}
