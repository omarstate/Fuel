import Foundation

// A fixed UTC gregorian calendar + date builder so the local-calendar logic
// ports test identically regardless of the machine's time zone.
enum TestCal {
  static let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }()

  static func date(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 0, _ minute: Int = 0,
    calendar: Calendar = utc
  ) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }
}
