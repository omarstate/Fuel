import Foundation
import Supabase

// CRUD on the personal workout log — public.workout_sessions,
// session_exercises and session_sets — via the supabase-swift client
// (PostgREST, RLS own-row). Mirrors the contract in
// frontend/src/app-editorial/workouts/session/use-active-session.ts +
// use-session-history.ts. The same live tables back the web app, so a set
// logged here shows up there instantly and vice versa.
//
// Every method throws and none of them touch UI state: view models own the
// optimistic apply and the rollback, matching the web's split.
struct WorkoutSessionRepository: Sendable {
  private var client: SupabaseClient { SupabaseService.shared.client }

  /// The signed-in user's id, fetched fresh from the session (never cached).
  func userID() async throws -> UUID {
    try await SupabaseService.shared.auth.session.user.id
  }

  // MARK: - Reads

  /// The session still running, if any. Filtered rather than `.single()` on
  /// purpose — `.single()` throws on zero rows, and "no session in flight" is
  /// the normal case, not an error.
  func inProgressSession() async throws -> WorkoutSession? {
    let userID = try await userID()
    let rows: [WorkoutSession] = try await client
      .from("workout_sessions")
      .select()
      .eq("user_id", value: userID.uuidString)
      .eq("status", value: SessionStatus.inProgress.rawValue)
      .order("started_at", ascending: false)
      .limit(1)
      .execute()
      .value
    return rows.first
  }

  /// One session with every exercise and set under it. Ordering of embeds is
  /// not guaranteed by PostgREST, so the model sorts on decode.
  func session(id: UUID) async throws -> SessionWithExercises {
    let userID = try await userID()
    return try await client
      .from("workout_sessions")
      .select("*, session_exercises(*, session_sets(*))")
      .eq("id", value: id.uuidString)
      .eq("user_id", value: userID.uuidString)
      .single()
      .execute()
      .value
  }

  /// Completed sessions from the last `days` (default 30), newest first, with
  /// just the ids needed to count exercises and sets.
  func history(days: Int = 30, now: Date = Date(), calendar: Calendar = .current) async throws -> [HistorySession] {
    let userID = try await userID()
    let since = DayBounds.addDays(DayBounds.startOfDay(now, calendar: calendar), -(days - 1), calendar: calendar)
    return try await client
      .from("workout_sessions")
      .select("*, session_exercises(id, session_sets(id))")
      .eq("user_id", value: userID.uuidString)
      .eq("status", value: SessionStatus.completed.rawValue)
      .gte("started_at", value: iso(since))
      .order("started_at", ascending: false)
      .execute()
      .value
  }

  /// The user's most recent completed sessions with everything under them,
  /// newest first — the data behind the picker's recents and the inline
  /// suggestions. Deliberately the FULL nested shape (unlike `history()`, which
  /// only counts): the ranking needs exercise names, positions and last sets.
  func recentSessions(limit: Int = 10) async throws -> [SessionWithExercises] {
    let userID = try await userID()
    return try await client
      .from("workout_sessions")
      .select("*, session_exercises(*, session_sets(*))")
      .eq("user_id", value: userID.uuidString)
      .eq("status", value: SessionStatus.completed.rawValue)
      .order("started_at", ascending: false)
      .limit(limit)
      .execute()
      .value
  }

  // MARK: - Writes

  /// Insert a client-generated session row. `session.userId` must be the
  /// session user for RLS to accept it — build it with `userID()`.
  func insertSession(_ session: WorkoutSession) async throws {
    try await client.from("workout_sessions").insert(session).execute()
  }

  func insertExercise(_ exercise: SessionExercise) async throws {
    try await client.from("session_exercises").insert(exercise).execute()
  }

  /// Removes the exercise; the sets under it go with it via ON DELETE CASCADE.
  func deleteExercise(id: UUID) async throws {
    try await client.from("session_exercises").delete().eq("id", value: id.uuidString).execute()
  }

  func insertSet(_ set: SessionSet) async throws {
    try await client.from("session_sets").insert(set).execute()
  }

  /// Full-field patch of an editable set. All three columns are always sent, so
  /// CLEARING one writes null instead of silently leaving the old value behind.
  func updateSet(id: UUID, weight: Double?, reps: Int?, note: String?) async throws {
    let patch = SetPatch(weight: weight, reps: reps, note: note)
    try await client.from("session_sets").update(patch).eq("id", value: id.uuidString).execute()
  }

  func deleteSet(id: UUID) async throws {
    try await client.from("session_sets").delete().eq("id", value: id.uuidString).execute()
  }

  /// Finish a session. Duration is recomputed from the two timestamps rather
  /// than from a ticking counter, so a backgrounded app still records the truth
  /// (port of `endSession` in use-active-session.ts, rounding the same way).
  func endSession(id: UUID, startedAt: Date, endedAt: Date) async throws {
    let patch = SessionEndPatch(
      status: SessionStatus.completed.rawValue,
      endedAt: iso(endedAt),
      durationSeconds: max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
    )
    try await client.from("workout_sessions").update(patch).eq("id", value: id.uuidString).execute()
  }

  // MARK: - Helpers

  private func iso(_ date: Date) -> String {
    ISO8601DateFormatter.fuelWithFractional.string(from: date)
  }

  // Hand-written encode so a nil optional emits an explicit null. The
  // synthesized encoder would use encodeIfPresent and OMIT the key, which
  // PostgREST reads as "leave this column alone" — the opposite of clearing it.
  private struct SetPatch: Encodable {
    let weight: Double?
    let reps: Int?
    let note: String?

    enum CodingKeys: String, CodingKey {
      case weight, reps, note
    }

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      if let weight { try c.encode(weight, forKey: .weight) } else { try c.encodeNil(forKey: .weight) }
      if let reps { try c.encode(reps, forKey: .reps) } else { try c.encodeNil(forKey: .reps) }
      if let note { try c.encode(note, forKey: .note) } else { try c.encodeNil(forKey: .note) }
    }
  }

  // Only the three columns finishing a session touches.
  private struct SessionEndPatch: Encodable {
    let status: String
    let endedAt: String
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
      case status
      case endedAt = "ended_at"
      case durationSeconds = "duration_seconds"
    }
  }
}
