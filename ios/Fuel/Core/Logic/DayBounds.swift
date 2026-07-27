import Foundation

// PURE Foundation port of frontend/src/app-editorial/day-bounds.ts. Local-
// calendar-day helpers shared by the Today log, 30-day History, streaks and the
// week chart, so they all agree where one day ends and the next begins.
//
// The TS uses the device's local calendar (`Date.setHours`, `getDay`,
// `getFullYear`…); we mirror that with `Calendar.current`. A calendar is
// injectable so tests are deterministic regardless of the machine's time zone.
enum DayBounds {
  /// Local midnight at the start of `date`'s calendar day.
  static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
    calendar.startOfDay(for: date)
  }

  /// `date` shifted by whole calendar days (DST-safe, like JS `setDate`).
  static func addDays(_ date: Date, _ days: Int, calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: days, to: date) ?? date
  }

  /// Local YYYY-MM-DD key for grouping timestamps into calendar days.
  static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// Seconds until the next local midnight, for scheduling a refresh.
  static func intervalUntilNextMidnight(from: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
    addDays(startOfDay(from, calendar: calendar), 1, calendar: calendar).timeIntervalSince(from)
  }
}
