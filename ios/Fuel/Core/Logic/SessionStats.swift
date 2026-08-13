import Foundation

// PURE Foundation aggregates over an in-flight or finished workout session.
// Ports the inline reducers in frontend/src/app-editorial/workouts/session/
// session-active.tsx (totals, session best, milestone toasts) into one tested
// place, so the header, the summary card and the toast logic can never drift.
enum SessionStats {
  /// Exercise count, set count and total volume for a session. Volume mirrors
  /// the web: Σ (weight ?? 0) × (reps ?? 0), so a bodyweight set contributes
  /// nothing rather than skewing the number.
  static func totals(exercises: [SessionExerciseWithSets]) -> (exercises: Int, sets: Int, volumeKg: Double) {
    var sets = 0
    var volume = 0.0
    for exercise in exercises {
      sets += exercise.sets.count
      for set in exercise.sets {
        volume += (set.weight ?? 0) * Double(set.reps ?? 0)
      }
    }
    return (exercises.count, sets, volume)
  }

  /// The number to stamp on the next set of an exercise.
  ///
  /// Deliberate divergence from the web, which uses `sets.length + 1`: numbering
  /// from the current maximum keeps set numbers unique after a mid-session
  /// delete (log 1,2,3 → delete 2 → the next set is 4, not a duplicate 3).
  static func nextSetNumber(existing: [SessionSet]) -> Int {
    (existing.map(\.setNumber).max() ?? 0) + 1
  }

  /// The heaviest weight logged anywhere in the session — the "session best"
  /// the web checks a new set against. nil when nothing carried a weight
  /// (an all-bodyweight session has no best, which is not the same as 0 kg).
  static func bestWeight(exercises: [SessionExerciseWithSets]) -> Double? {
    exercises.flatMap(\.sets).compactMap(\.weight).max()
  }

  /// Whether landing on `totalSetCount` sets deserves a celebration — every 5th
  /// set, matching `nextSets % 5 === 0` in session-active.tsx. Zero is not one.
  static func isMilestone(totalSetCount: Int) -> Bool {
    totalSetCount > 0 && totalSetCount % 5 == 0
  }

  /// Whole seconds between two instants, clamped at zero so a clock skew can
  /// never render a negative timer. Floors, like the web's live SessionTimer.
  static func elapsedSeconds(from: Date, to: Date) -> Int {
    max(0, Int(to.timeIntervalSince(from).rounded(.down)))
  }
}
