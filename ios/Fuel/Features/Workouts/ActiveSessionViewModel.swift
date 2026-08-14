import Foundation
import Observation

// Drives one in-flight workout session. Port of the contract in
// workouts/session/use-active-session.ts: every mutation applies locally FIRST
// and rolls back if the write throws, because a gym has bad signal and a set you
// just logged must appear the instant your thumb leaves the button.
//
// One deliberate divergence from the web: there is no temp-id dance. Postgres
// ids here are client-generated UUIDs (see WorkoutSessionRepository), so the row
// inserted optimistically IS the real row — nothing has to be reconciled after
// the insert returns, and a rollback is a plain removal by id.
//
// Every mutation returns Bool rather than throwing: the caller needs to know
// whether to start a rest timer or fire a milestone, and the error is already
// surfaced through `error` for the banner.
@MainActor
@Observable
final class ActiveSessionViewModel {
  let sessionId: UUID

  private(set) var session: SessionWithExercises?
  private(set) var isLoading = false
  var error: PresentableError?

  @ObservationIgnored private let repository = WorkoutSessionRepository()

  init(sessionId: UUID) {
    self.sessionId = sessionId
  }

  /// Preview seam: a model already holding a session, so SwiftUI previews render
  /// the real layout without a network round-trip or a signed-in user.
  static func preview(_ session: SessionWithExercises) -> ActiveSessionViewModel {
    let model = ActiveSessionViewModel(sessionId: session.id)
    model.session = session
    return model
  }

  // MARK: - Derived

  var exercises: [SessionExerciseWithSets] { session?.exercises ?? [] }

  var totals: (exercises: Int, sets: Int, volumeKg: Double) {
    SessionStats.totals(exercises: exercises)
  }

  var totalSetCount: Int { totals.sets }

  /// The heaviest weight anywhere in the session, or nil for an all-bodyweight
  /// session. Read BEFORE a set lands to decide whether it is a new best.
  var bestWeight: Double? { SessionStats.bestWeight(exercises: exercises) }

  var categoryName: String? { session?.categoryName }
  var categorySlug: String? { session?.categorySlug }
  var startedAt: Date? { session?.startedAt }

  /// Exercise names already in the session, for filtering the catalog chips.
  var existingNames: Set<String> {
    Set(exercises.map { $0.name.lowercased() })
  }

  // MARK: - Loading

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      session = try await repository.session(id: sessionId)
      error = nil
    } catch {
      self.error = PresentableError.presentable(error)
    }
  }

  // MARK: - Exercises

  @discardableResult
  func addExercise(name: String, workoutId: String?) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let userID: UUID
    do {
      userID = try await repository.userID()
    } catch {
      self.error = PresentableError(error)
      return false
    }

    // Re-read the session AFTER the await — it may have loaded or changed while
    // the auth session was being fetched.
    guard let current = session else { return false }
    let row = SessionExercise(
      sessionId: current.id,
      userId: userID,
      workoutId: workoutId,
      name: trimmed,
      position: current.exercises.count
    )
    let entry = SessionExerciseWithSets(exercise: row, sets: [])
    apply(current.exercises + [entry])

    do {
      try await repository.insertExercise(row)
      return true
    } catch {
      apply(exercises.filter { $0.id != row.id })
      self.error = PresentableError(error)
      return false
    }
  }

  @discardableResult
  func deleteExercise(_ exercise: SessionExerciseWithSets) async -> Bool {
    guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return false }
    var next = exercises
    next.remove(at: index)
    apply(next)

    do {
      try await repository.deleteExercise(id: exercise.id)
      return true
    } catch {
      var restored = exercises
      restored.insert(exercise, at: min(index, restored.count))
      apply(restored)
      self.error = PresentableError(error)
      return false
    }
  }

  // MARK: - Sets

  @discardableResult
  func logSet(exerciseId: UUID, weight: Double?, reps: Int?, note: String? = nil) async -> Bool {
    let userID: UUID
    do {
      userID = try await repository.userID()
    } catch {
      self.error = PresentableError(error)
      return false
    }

    guard let index = exercises.firstIndex(where: { $0.id == exerciseId }) else { return false }
    let target = exercises[index]
    let row = SessionSet(
      sessionExerciseId: exerciseId,
      userId: userID,
      setNumber: SessionStats.nextSetNumber(existing: target.sets),
      weight: weight,
      reps: reps,
      note: note
    )
    apply(replacingSets(of: exerciseId, with: target.sets + [row]))

    do {
      try await repository.insertSet(row)
      return true
    } catch {
      apply(mapSets { $0.filter { set in set.id != row.id } })
      self.error = PresentableError(error)
      return false
    }
  }

  @discardableResult
  func updateSet(id: UUID, weight: Double?, reps: Int?, note: String?) async -> Bool {
    let snapshot = exercises
    guard snapshot.contains(where: { $0.sets.contains(where: { $0.id == id }) }) else { return false }

    apply(mapSets { sets in
      sets.map { set in
        guard set.id == id else { return set }
        var patched = set
        patched.weight = weight
        patched.reps = reps
        patched.note = note
        return patched
      }
    })

    do {
      try await repository.updateSet(id: id, weight: weight, reps: reps, note: note)
      return true
    } catch {
      apply(snapshot)
      self.error = PresentableError(error)
      return false
    }
  }

  @discardableResult
  func deleteSet(id: UUID) async -> Bool {
    let snapshot = exercises
    guard snapshot.contains(where: { $0.sets.contains(where: { $0.id == id }) }) else { return false }
    apply(mapSets { $0.filter { set in set.id != id } })

    do {
      try await repository.deleteSet(id: id)
      return true
    } catch {
      apply(snapshot)
      self.error = PresentableError(error)
      return false
    }
  }

  // MARK: - Ending

  /// Completes the session. Duration is recomputed from the two timestamps by
  /// the repository, so a backgrounded app still records the real elapsed time.
  func endSession() async -> Bool {
    guard let current = session else { return false }
    let endedAt = Date()
    do {
      try await repository.endSession(id: current.id, startedAt: current.startedAt, endedAt: endedAt)
      var ended = current.session
      ended.status = .completed
      ended.endedAt = endedAt
      ended.durationSeconds = SessionStats.elapsedSeconds(from: current.startedAt, to: endedAt)
      session = SessionWithExercises(session: ended, exercises: current.exercises)
      return true
    } catch {
      self.error = PresentableError(error)
      return false
    }
  }

  // MARK: - Local state helpers

  // SessionWithExercises is an immutable read shape, so every local edit
  // rebuilds it around the same base row.
  private func apply(_ exercises: [SessionExerciseWithSets]) {
    guard let current = session else { return }
    session = SessionWithExercises(session: current.session, exercises: exercises)
  }

  private func replacingSets(of exerciseId: UUID, with sets: [SessionSet]) -> [SessionExerciseWithSets] {
    exercises.map { entry in
      guard entry.id == exerciseId else { return entry }
      return SessionExerciseWithSets(exercise: entry.exercise, sets: sets)
    }
  }

  /// Rewrite the set list of every exercise — used by the update/delete paths,
  /// which only know a set id, not which exercise owns it.
  private func mapSets(_ transform: ([SessionSet]) -> [SessionSet]) -> [SessionExerciseWithSets] {
    exercises.map { SessionExerciseWithSets(exercise: $0.exercise, sets: transform($0.sets)) }
  }
}
