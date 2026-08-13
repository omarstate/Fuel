import Testing
import Foundation
@testable import Fuel

// The ranking behind the add-exercise card and the picker sheet. The rules worth
// pinning down: recency wins over everything (newest session, newest instance,
// last set), the session you are IN never suggests what it already holds, and a
// name is one name however you capitalised it last time.
@Suite("Exercise picker")
struct ExercisePickerTests {
  private let userID = UUID()

  /// A completed session, newest-first ordering left to the caller.
  private func session(
    slug: String?,
    startedAt: Date = Date(),
    exercises: [(name: String, workoutId: String?, sets: [(Int, Double?, Int?)])]
  ) -> SessionWithExercises {
    let sessionID = UUID()
    return SessionWithExercises(
      session: WorkoutSession(
        id: sessionID,
        userId: userID,
        categoryName: slug?.capitalized,
        categorySlug: slug,
        status: .completed,
        startedAt: startedAt
      ),
      exercises: exercises.enumerated().map { position, entry in
        let exerciseID = UUID()
        return SessionExerciseWithSets(
          exercise: SessionExercise(
            id: exerciseID, sessionId: sessionID, userId: userID,
            workoutId: entry.workoutId, name: entry.name, position: position
          ),
          sets: entry.sets.map { number, weight, reps in
            SessionSet(
              sessionExerciseId: exerciseID, userId: userID,
              setNumber: number, weight: weight, reps: reps
            )
          }
        )
      }
    )
  }

  private func workout(_ id: String, _ name: String) -> Workout {
    Workout(
      id: id, name: name, description: nil,
      primaryMuscle: nil, equipment: nil,
      targetSets: nil, targetReps: nil,
      categories: [], createdAt: nil
    )
  }

  // MARK: - recents

  @Test("recents follow session order, then position within a session")
  func recentsOrder() {
    let sessions = [
      session(slug: "push", exercises: [
        ("Bench press", "w1", [(1, 60, 10)]),
        ("Cable fly", "w2", [(1, 20, 12)]),
      ]),
      session(slug: "pull", exercises: [
        ("Barbell row", "w3", [(1, 70, 8)]),
      ]),
    ]
    let recents = ExercisePicker.recents(from: sessions)
    #expect(recents.map(\.name) == ["Bench press", "Cable fly", "Barbell row"])
    #expect(recents.map(\.workoutId) == ["w1", "w2", "w3"])
  }

  @Test("a repeated name is deduped case-insensitively, keeping the newest")
  func recentsDedupe() {
    let sessions = [
      session(slug: "push", exercises: [("Bench press", "w1", [(1, 90, 5)])]),
      session(slug: "push", exercises: [("BENCH PRESS", "w1", [(1, 60, 10)])]),
    ]
    let recents = ExercisePicker.recents(from: sessions)
    #expect(recents.count == 1)
    #expect(recents[0].name == "Bench press")   // the newest spelling
    #expect(recents[0].lastWeight == 90)        // and the newest numbers
  }

  @Test("the last set of the newest instance wins, by set number not array order")
  func recentsLastSet() {
    let sessions = [
      session(slug: "push", exercises: [
        ("Bench press", "w1", [(1, 60, 10), (3, 90, 3), (2, 80, 6)]),
      ]),
    ]
    let recents = ExercisePicker.recents(from: sessions)
    #expect(recents[0].lastWeight == 90)
    #expect(recents[0].lastReps == 3)
  }

  @Test("an exercise logged with no sets has no weight or reps")
  func recentsNoSets() {
    let sessions = [session(slug: "push", exercises: [("Bench press", nil, [])])]
    let recents = ExercisePicker.recents(from: sessions)
    #expect(recents[0].lastWeight == nil)
    #expect(recents[0].lastReps == nil)
    #expect(recents[0].lastSetLabel == nil)
  }

  @Test("no sessions, no recents")
  func recentsEmpty() {
    #expect(ExercisePicker.recents(from: []).isEmpty)
  }

  // MARK: - suggestions

  @Test("the last same-category session leads, in position order")
  func suggestionsSameCategoryFirst() {
    let sessions = [
      session(slug: "pull", exercises: [("Barbell row", "w9", [])]),
      session(slug: "push", exercises: [
        ("Bench press", "w1", []),
        ("Cable fly", "w2", []),
      ]),
    ]
    let result = ExercisePicker.suggestions(
      sessions: sessions,
      categorySlug: "push",
      catalog: [workout("c1", "Overhead press")],
      existingNames: []
    )
    #expect(result.map(\.name) == ["Bench press", "Cable fly", "Overhead press"])
    #expect(result.map(\.workoutId) == ["w1", "w2", "c1"])
  }

  @Test("a nil category skips the history source entirely")
  func suggestionsNilCategory() {
    let sessions = [session(slug: "push", exercises: [("Bench press", "w1", [])])]
    let result = ExercisePicker.suggestions(
      sessions: sessions,
      categorySlug: nil,
      catalog: [workout("c1", "Overhead press")],
      existingNames: []
    )
    #expect(result.map(\.name) == ["Overhead press"])
  }

  @Test("exercises already in the session never come back as suggestions")
  func suggestionsExcludeExisting() {
    let sessions = [
      session(slug: "push", exercises: [
        ("Bench press", "w1", []),
        ("Cable fly", "w2", []),
      ]),
    ]
    let result = ExercisePicker.suggestions(
      sessions: sessions,
      categorySlug: "push",
      catalog: [workout("c1", "Cable fly"), workout("c2", "Dips")],
      existingNames: ["bench press"]
    )
    #expect(result.map(\.name) == ["Cable fly", "Dips"])
  }

  @Test("a name in both history and the catalog appears once")
  func suggestionsDedupe() {
    let sessions = [session(slug: "push", exercises: [("Bench press", "w1", [])])]
    let result = ExercisePicker.suggestions(
      sessions: sessions,
      categorySlug: "push",
      catalog: [workout("c1", "BENCH PRESS"), workout("c2", "Dips")],
      existingNames: []
    )
    #expect(result == [
      .init(name: "Bench press", workoutId: "w1"),
      .init(name: "Dips", workoutId: "c2"),
    ])
  }

  @Test("the list is capped at the limit")
  func suggestionsLimit() {
    let catalog = (1...20).map { workout("c\($0)", "Exercise \($0)") }
    #expect(ExercisePicker.suggestions(
      sessions: [], categorySlug: nil, catalog: catalog, existingNames: []
    ).count == 6)
    #expect(ExercisePicker.suggestions(
      sessions: [], categorySlug: nil, catalog: catalog, existingNames: [], limit: 3
    ).count == 3)
  }

  @Test("only the NEWEST session of the category is used, not every one")
  func suggestionsNewestSessionOnly() {
    let sessions = [
      session(slug: "push", exercises: [("Bench press", "w1", [])]),
      session(slug: "push", exercises: [("Machine press", "w4", [])]),
    ]
    let result = ExercisePicker.suggestions(
      sessions: sessions, categorySlug: "push", catalog: [], existingNames: []
    )
    #expect(result.map(\.name) == ["Bench press"])
  }

  // MARK: - matches

  @Test("search is a case-insensitive substring, and empty matches everything")
  func matches() {
    #expect(ExercisePicker.matches(name: "Barbell bench press", query: "BENCH"))
    #expect(ExercisePicker.matches(name: "Barbell bench press", query: "press"))
    #expect(!ExercisePicker.matches(name: "Barbell bench press", query: "squat"))
    #expect(ExercisePicker.matches(name: "Anything", query: ""))
    #expect(ExercisePicker.matches(name: "Anything", query: "   "))
  }

  // MARK: - lastSetLabel

  @Test("last-set labels drop trailing zeros and read bodyweight as BW")
  func lastSetLabel() {
    #expect(ExercisePicker.lastSetLabel(weight: 80, reps: 8, hasAny: true) == "80 × 8")
    #expect(ExercisePicker.lastSetLabel(weight: 82.5, reps: 6, hasAny: true) == "82.5 × 6")
    #expect(ExercisePicker.lastSetLabel(weight: nil, reps: 8, hasAny: true) == "BW × 8")
    #expect(ExercisePicker.lastSetLabel(weight: 100, reps: nil, hasAny: true) == "100")
    #expect(ExercisePicker.lastSetLabel(weight: nil, reps: nil, hasAny: true) == nil)
    #expect(ExercisePicker.lastSetLabel(weight: 80, reps: 8, hasAny: false) == nil)
  }
}
