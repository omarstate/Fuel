import Foundation

// PURE Foundation ports of the three number formatters the workout session UI
// shares, so the live timer, the history list and the session detail header all
// render a value the same way.
//
// All three are POSIX by design, exactly like the TS they come from
// (`String(padStart)` / `toFixed`): these are machine-shaped readouts rendered in
// JetBrains Mono, not localized prose. User INPUT still goes through
// NumberParsing.
enum DurationFormat {
  /// Elapsed session time as `H:MM:SS`. Port of `formatDuration` in
  /// workouts/session/session-timer.tsx — note the web always shows the hour
  /// component, so 90 seconds reads "0:01:30", never "1:30".
  static func elapsed(_ seconds: Int) -> String {
    let total = max(0, seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return String(format: "%d:%02d:%02d", h, m, s)
  }

  /// Rest countdown as `M:SS`. Port of `fmtRest` in
  /// workouts/session/rest-timer.tsx — minutes are never zero-padded, so 90
  /// reads "1:30" and 45 reads "0:45".
  static func rest(_ seconds: Int) -> String {
    let total = max(0, seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// A logged weight in kg: whole numbers bare, everything else to one decimal
  /// ("80", "82.5"). Port of `fmtWeight` in workouts/session/set-logger.tsx and
  /// active-exercise-card.tsx.
  static func weight(_ kg: Double) -> String {
    guard kg.isFinite else { return "0" }
    return kg == kg.rounded() ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
  }
}
