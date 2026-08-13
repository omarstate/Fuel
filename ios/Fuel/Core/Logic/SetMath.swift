import Foundation

// PURE Foundation guards and arithmetic for a logged set. Voice parsing hands us
// numbers a language model chose, so every weight and rep count passes through
// here before it reaches a numeric(6,2) column or a volume readout.
//
// Set NUMBERING deliberately lives elsewhere: `SessionStats.nextSetNumber` is the
// one place that decides it (it numbers from the max, not the count, so a
// mid-session delete can't hand out a duplicate). Call that — do not re-derive it.
enum SetMath {
  /// Above this a "weight" is a mis-heard rep count or a phone number, not a
  /// barbell. Also the ceiling of the numeric(6,2) column.
  static let maxWeightKg: Double = 500
  static let maxReps = 100

  /// A usable kilogram weight, rounded to the column's 2 decimal places, or nil.
  ///
  /// The range is (0, 500]: zero is not a light weight, it is BODYWEIGHT, which
  /// the schema stores as null and the UI renders as "BW". The bound is checked
  /// BEFORE rounding on purpose — 500.004 is out of range and comes back nil
  /// rather than being quietly rounded into a legal 500.
  static func clampWeight(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value > 0, value <= maxWeightKg else { return nil }
    return (value * 100).rounded() / 100
  }

  /// A usable rep count, or nil. Zero reps is not a set, and three digits is a
  /// mis-heard weight.
  static func clampReps(_ value: Int?) -> Int? {
    guard let value, value >= 1, value <= maxReps else { return nil }
    return value
  }

  /// Σ weight × reps, matching `SessionStats.totals`: a bodyweight or rep-less
  /// set contributes nothing rather than skewing the number.
  static func volume(sets: [SessionSet]) -> Double {
    volume(sets: sets.map { (weight: $0.weight, reps: $0.reps) })
  }

  /// The same sum over rows that aren't persisted yet — the voice review sheet
  /// totals what you're about to log before any of it exists in the database.
  static func volume(sets: [(weight: Double?, reps: Int?)]) -> Double {
    sets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
  }
}
