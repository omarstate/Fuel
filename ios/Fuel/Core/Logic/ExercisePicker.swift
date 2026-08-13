import Foundation

// PURE Foundation logic behind "add an exercise": what to suggest inline, what
// counts as a recent, and how the two render.
//
// It lives here rather than in the views because the ranking is the interesting
// part — a lifter opening a Push session wants the exercises they did LAST push
// day, in the order they did them, not an alphabetical dump of the catalog. That
// rule is worth testing, and it can be, because nothing in this file touches
// SwiftUI, the network or Supabase.
enum ExercisePicker {
  /// One exercise the user has done before, with the last set they logged on it
  /// — the picker's "Recent" row.
  struct Recent: Equatable, Identifiable, Sendable {
    let name: String
    let workoutId: String?
    /// Weight of the most recent logged set of the most recent instance; nil for
    /// a bodyweight set (renders "BW") or when that instance had no sets.
    let lastWeight: Double?
    let lastReps: Int?

    /// Deduped case-insensitively upstream, so the folded name is a stable id.
    var id: String { name.lowercased() }

    /// "80 × 8" / "BW × 12", or nil when the last instance logged nothing.
    var lastSetLabel: String? {
      ExercisePicker.lastSetLabel(
        weight: lastWeight,
        reps: lastReps,
        hasAny: lastWeight != nil || lastReps != nil
      )
    }
  }

  /// One inline chip / one pick. A named struct rather than the tuple this
  /// started as, so it can drive an `Identifiable` ForEach and be compared
  /// whole in tests.
  struct Suggestion: Equatable, Identifiable, Sendable {
    let name: String
    let workoutId: String?

    var id: String { name.lowercased() }

    init(name: String, workoutId: String? = nil) {
      self.name = name
      self.workoutId = workoutId
    }
  }

  /// Recents across sessions, deduped by case-insensitive name, newest first.
  ///
  /// `sessions` must arrive newest-first (that is what
  /// `WorkoutSessionRepository.recentSessions()` returns); within a session the
  /// exercises keep their position order. Weight and reps come from the LAST set
  /// (highest `setNumber`) of the NEWEST instance of that exercise, so a name
  /// seen again in an older session never overwrites the fresher numbers.
  static func recents(from sessions: [SessionWithExercises]) -> [Recent] {
    var seen = Set<String>()
    var out: [Recent] = []
    for session in sessions {
      for exercise in session.exercises.sorted(by: { $0.position < $1.position }) {
        let key = exercise.name.lowercased()
        guard !seen.contains(key) else { continue }
        seen.insert(key)
        let last = exercise.sets.max(by: { $0.setNumber < $1.setNumber })
        out.append(
          Recent(
            name: exercise.name,
            workoutId: exercise.workoutId,
            lastWeight: last?.weight,
            lastReps: last?.reps
          )
        )
      }
    }
    return out
  }

  /// The inline suggestion list, capped at `limit`, drawn from two sources in
  /// order:
  ///
  /// 1. the exercises of the newest completed session in the SAME category, in
  ///    the order they were done (nil/empty `categorySlug` — on the parameter or
  ///    on every session — skips this source),
  /// 2. topped up with `catalog` names in the order given.
  ///
  /// Anything already in the session (`existingNames`, pre-lowercased) is
  /// excluded, and names are deduped across both sources.
  static func suggestions(
    sessions: [SessionWithExercises],
    categorySlug: String?,
    catalog: [Workout],
    existingNames: Set<String>,
    limit: Int = 6
  ) -> [Suggestion] {
    guard limit > 0 else { return [] }
    var seen = existingNames
    var out: [Suggestion] = []

    func append(name: String, workoutId: String?) {
      guard out.count < limit else { return }
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let key = trimmed.lowercased()
      guard !trimmed.isEmpty, !seen.contains(key) else { return }
      seen.insert(key)
      out.append(Suggestion(name: trimmed, workoutId: workoutId))
    }

    if let categorySlug, !categorySlug.isEmpty,
       let last = sessions.first(where: {
         $0.categorySlug?.caseInsensitiveCompare(categorySlug) == .orderedSame
       }) {
      for exercise in last.exercises.sorted(by: { $0.position < $1.position }) {
        append(name: exercise.name, workoutId: exercise.workoutId)
      }
    }

    for workout in catalog {
      append(name: workout.name, workoutId: workout.id)
    }
    return out
  }

  /// The case-insensitive "contains" filter behind the picker's search. An empty
  /// (or whitespace-only) query matches everything — search narrows, it never
  /// hides the catalog before you have typed.
  static func matches(name: String, query: String) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return true }
    return name.lowercased().contains(needle.lowercased())
  }

  /// The "Last: 80 × 8" readout. Weight goes through `DurationFormat.weight`, so
  /// it loses trailing zeros (80, 82.5) exactly like the set logger; a nil
  /// weight is bodyweight and reads "BW". nil when there is nothing to show at
  /// all — an exercise logged with no sets gets no subtitle rather than an empty
  /// one.
  static func lastSetLabel(weight: Double?, reps: Int?, hasAny: Bool) -> String? {
    guard hasAny, weight != nil || reps != nil else { return nil }
    let weightText = weight.map(DurationFormat.weight) ?? "BW"
    guard let reps else { return weightText }
    return "\(weightText) × \(reps)"
  }
}
