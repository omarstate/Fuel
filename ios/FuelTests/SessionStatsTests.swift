import Testing
import Foundation
@testable import Fuel

// Hand-computed against the reducers in
// frontend/src/app-editorial/workouts/session/session-active.tsx: volume skips
// bodyweight sets, the session best ignores them too, and a milestone fires
// every 5th set. `nextSetNumber` intentionally does NOT match the web — see the
// post-delete case below.
@Suite("Session stats")
struct SessionStatsTests {
  private let sessionID = UUID()
  private let userID = UUID()

  private func exercise(_ name: String, position: Int, sets: [(Int, Double?, Int?)]) -> SessionExerciseWithSets {
    let exerciseID = UUID()
    return SessionExerciseWithSets(
      exercise: SessionExercise(
        id: exerciseID, sessionId: sessionID, userId: userID, name: name, position: position
      ),
      sets: sets.map { number, weight, reps in
        SessionSet(
          sessionExerciseId: exerciseID, userId: userID,
          setNumber: number, weight: weight, reps: reps
        )
      }
    )
  }

  // MARK: - totals

  @Test("totals sum sets and volume across exercises")
  func totals() {
    let exercises = [
      exercise("Bench", position: 1, sets: [(1, 60, 10), (2, 80, 5)]),
      exercise("Row", position: 2, sets: [(1, 50, 12)]),
    ]
    let result = SessionStats.totals(exercises: exercises)
    #expect(result.exercises == 2)
    #expect(result.sets == 3)
    #expect(result.volumeKg == 600 + 400 + 600)  // 1600
  }

  @Test("null weights and reps contribute nothing to volume")
  func totalsWithNulls() {
    let exercises = [
      exercise("Pull-up", position: 1, sets: [(1, nil, 8), (2, 20, nil), (3, nil, nil)]),
    ]
    let result = SessionStats.totals(exercises: exercises)
    #expect(result.exercises == 1)
    #expect(result.sets == 3)   // they still COUNT as sets
    #expect(result.volumeKg == 0)
  }

  @Test("an empty session totals to zero")
  func totalsEmpty() {
    let result = SessionStats.totals(exercises: [])
    #expect(result.exercises == 0)
    #expect(result.sets == 0)
    #expect(result.volumeKg == 0)
  }

  // MARK: - nextSetNumber

  @Test("the first set of an exercise is number 1")
  func nextSetNumberEmpty() {
    #expect(SessionStats.nextSetNumber(existing: []) == 1)
  }

  @Test("numbering continues from the max, so a mid-session delete can't duplicate")
  func nextSetNumberAfterDelete() {
    // Logged 1,2,3 then deleted 2 — the web's count+1 would hand out 3 again.
    let exerciseID = UUID()
    let existing = [1, 3].map {
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: $0, weight: 60, reps: 8)
    }
    #expect(SessionStats.nextSetNumber(existing: existing) == 4)
  }

  // MARK: - bestWeight

  @Test("bestWeight is the heaviest set anywhere in the session")
  func bestWeight() {
    let exercises = [
      exercise("Bench", position: 1, sets: [(1, 60, 10), (2, 80, 5)]),
      exercise("Squat", position: 2, sets: [(1, 100, 5)]),
    ]
    #expect(SessionStats.bestWeight(exercises: exercises) == 100)
  }

  @Test("an all-bodyweight session has no best — nil, not zero")
  func bestWeightBodyweight() {
    let exercises = [exercise("Push-up", position: 1, sets: [(1, nil, 20), (2, nil, 18)])]
    #expect(SessionStats.bestWeight(exercises: exercises) == nil)
  }

  @Test("a session with no sets at all has no best")
  func bestWeightEmpty() {
    #expect(SessionStats.bestWeight(exercises: []) == nil)
    #expect(SessionStats.bestWeight(exercises: [exercise("Bench", position: 1, sets: [])]) == nil)
  }

  // MARK: - isMilestone

  @Test("a milestone fires on every 5th set, never on zero")
  func milestones() {
    #expect(SessionStats.isMilestone(totalSetCount: 0) == false)
    #expect(SessionStats.isMilestone(totalSetCount: 1) == false)
    #expect(SessionStats.isMilestone(totalSetCount: 4) == false)
    #expect(SessionStats.isMilestone(totalSetCount: 5) == true)
    #expect(SessionStats.isMilestone(totalSetCount: 9) == false)
    #expect(SessionStats.isMilestone(totalSetCount: 10) == true)
    #expect(SessionStats.isMilestone(totalSetCount: 25) == true)
  }

  // MARK: - elapsedSeconds

  @Test("elapsed seconds floor the interval")
  func elapsed() {
    let start = TestCal.date(2026, 7, 19, 18, 30)
    #expect(SessionStats.elapsedSeconds(from: start, to: start) == 0)
    #expect(SessionStats.elapsedSeconds(from: start, to: start.addingTimeInterval(90)) == 90)
    #expect(SessionStats.elapsedSeconds(from: start, to: start.addingTimeInterval(90.9)) == 90)
  }

  @Test("a clock going backwards clamps at zero instead of showing a negative timer")
  func elapsedClamps() {
    let start = TestCal.date(2026, 7, 19, 18, 30)
    #expect(SessionStats.elapsedSeconds(from: start, to: start.addingTimeInterval(-120)) == 0)
  }
}
