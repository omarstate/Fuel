import Foundation

// Shared date presentation for the editorial mastheads and history headers.
// Locale-aware (via Date.FormatStyle) so ar-EG picks up correctly in M6.
enum FuelDateFormat {
  /// "Saturday, July 19" — the Today masthead / long day headers.
  static func masthead(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.wide).month(.wide).day())
  }

  /// "Monday, Jul 20" — the small eyebrow above the Today/Overview masthead
  /// (the `.fuelEyebrow()` modifier uppercases it to "MONDAY, JUL 20").
  static func eyebrow(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
  }

  /// "Today" / "Yesterday" / long date — History day-group headers.
  static func dayHeader(_ date: Date, calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) { return String(localized: "Today") }
    if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
    return masthead(date)
  }
}
