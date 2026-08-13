import Foundation

// Rows in public.workout_sessions / session_exercises / session_sets — the
// user's personal workout log (RLS own-row). Written directly with supabase-js
// on the web (frontend/src/app-editorial/workouts/session/use-*.ts) and with
// supabase-swift here; the same live tables back both clients, so these are a
// direct port of that folder's types.ts row mappers.
//
// Coding is fully self-contained (snake_case keys, explicit ISO8601 timestamp
// strings, lenient numeric weight) so the models round-trip identically whether
// the PostgREST client's coders drive them or a plain pair in tests.

enum SessionStatus: String, Codable, Sendable {
  case inProgress = "in_progress"
  case completed
}

struct WorkoutSession: Codable, Identifiable, Equatable, Sendable {
  var id: UUID
  var userId: UUID
  /// The catalog category this session was started from, snapshotted by name +
  /// slug so a renamed or deleted category never rewrites history.
  var categoryId: String?
  var categoryName: String?
  var categorySlug: String?
  var status: SessionStatus
  var startedAt: Date
  var endedAt: Date?
  var durationSeconds: Int?
  var notes: String?
  /// Absent on a row we just built to insert — the DB fills it in.
  var createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case categoryId = "category_id"
    case categoryName = "category_name"
    case categorySlug = "category_slug"
    case status
    case startedAt = "started_at"
    case endedAt = "ended_at"
    case durationSeconds = "duration_seconds"
    case notes
    case createdAt = "created_at"
  }

  init(
    id: UUID = UUID(),
    userId: UUID,
    categoryId: String? = nil,
    categoryName: String? = nil,
    categorySlug: String? = nil,
    status: SessionStatus = .inProgress,
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    durationSeconds: Int? = nil,
    notes: String? = nil,
    createdAt: Date? = nil
  ) {
    self.id = id
    self.userId = userId
    self.categoryId = categoryId
    self.categoryName = categoryName
    self.categorySlug = categorySlug
    self.status = status
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.durationSeconds = durationSeconds
    self.notes = notes
    self.createdAt = createdAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    userId = try c.decode(UUID.self, forKey: .userId)
    categoryId = try c.decodeIfPresent(String.self, forKey: .categoryId)
    categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName)
    categorySlug = try c.decodeIfPresent(String.self, forKey: .categorySlug)
    status = try c.decode(SessionStatus.self, forKey: .status)
    startedAt = try SessionTime.required(c, .startedAt)
    endedAt = try SessionTime.optional(c, .endedAt)
    durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
    notes = try c.decodeIfPresent(String.self, forKey: .notes)
    createdAt = try SessionTime.optional(c, .createdAt)
  }

  // Encodes exactly the columns an insert needs. `created_at` is deliberately
  // omitted so the DB default wins; every other optional sends an explicit null.
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encode(categoryId, forKey: .categoryId)
    try c.encode(categoryName, forKey: .categoryName)
    try c.encode(categorySlug, forKey: .categorySlug)
    try c.encode(status, forKey: .status)
    try c.encode(SessionTime.string(startedAt), forKey: .startedAt)
    try c.encode(endedAt.map(SessionTime.string), forKey: .endedAt)
    try c.encode(durationSeconds, forKey: .durationSeconds)
    try c.encode(notes, forKey: .notes)
  }
}

struct SessionExercise: Codable, Identifiable, Equatable, Sendable {
  var id: UUID
  var sessionId: UUID
  var userId: UUID
  /// The catalog workout this came from; nil for a one-off custom exercise.
  var workoutId: String?
  /// Snapshotted at add time so a renamed catalog workout never rewrites history.
  var name: String
  var position: Int
  var createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case sessionId = "session_id"
    case userId = "user_id"
    case workoutId = "workout_id"
    case name
    case position
    case createdAt = "created_at"
  }

  init(
    id: UUID = UUID(),
    sessionId: UUID,
    userId: UUID,
    workoutId: String? = nil,
    name: String,
    position: Int,
    createdAt: Date? = nil
  ) {
    self.id = id
    self.sessionId = sessionId
    self.userId = userId
    self.workoutId = workoutId
    self.name = name
    self.position = position
    self.createdAt = createdAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    sessionId = try c.decode(UUID.self, forKey: .sessionId)
    userId = try c.decode(UUID.self, forKey: .userId)
    workoutId = try c.decodeIfPresent(String.self, forKey: .workoutId)
    name = try c.decode(String.self, forKey: .name)
    position = try c.decode(Int.self, forKey: .position)
    createdAt = try SessionTime.optional(c, .createdAt)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(sessionId, forKey: .sessionId)
    try c.encode(userId, forKey: .userId)
    try c.encode(workoutId, forKey: .workoutId)
    try c.encode(name, forKey: .name)
    try c.encode(position, forKey: .position)
  }
}

struct SessionSet: Codable, Identifiable, Equatable, Sendable {
  var id: UUID
  var sessionExerciseId: UUID
  var userId: UUID
  var setNumber: Int
  /// Kilograms. nil means bodyweight — the UI renders "BW", not zero.
  var weight: Double?
  var reps: Int?
  var note: String?
  var createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case sessionExerciseId = "session_exercise_id"
    case userId = "user_id"
    case setNumber = "set_number"
    case weight
    case reps
    case note
    case createdAt = "created_at"
  }

  init(
    id: UUID = UUID(),
    sessionExerciseId: UUID,
    userId: UUID,
    setNumber: Int,
    weight: Double? = nil,
    reps: Int? = nil,
    note: String? = nil,
    createdAt: Date? = nil
  ) {
    self.id = id
    self.sessionExerciseId = sessionExerciseId
    self.userId = userId
    self.setNumber = setNumber
    self.weight = weight
    self.reps = reps
    self.note = note
    self.createdAt = createdAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    sessionExerciseId = try c.decode(UUID.self, forKey: .sessionExerciseId)
    userId = try c.decode(UUID.self, forKey: .userId)
    setNumber = try c.decode(Int.self, forKey: .setNumber)
    weight = Self.lenientWeight(c, .weight)
    reps = try c.decodeIfPresent(Int.self, forKey: .reps)
    note = try c.decodeIfPresent(String.self, forKey: .note)
    createdAt = try SessionTime.optional(c, .createdAt)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(sessionExerciseId, forKey: .sessionExerciseId)
    try c.encode(userId, forKey: .userId)
    try c.encode(setNumber, forKey: .setNumber)
    try c.encode(weight, forKey: .weight)
    try c.encode(reps, forKey: .reps)
    try c.encode(note, forKey: .note)
  }

  // `weight` is numeric(6,2): PostgREST may hand it over as a JSON number OR as
  // a quoted string ("62.50"). The string is machine JSON, so it parses with the
  // POSIX `Double(_:)` — never NumberParsing, which is for user input.
  private static func lenientWeight(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
    return nil
  }
}

// MARK: - Nested read shapes

// An exercise with its sets, from the embed `session_exercises(*, session_sets(*))`.
// The base row is decoded from the same container, so SessionExercise stays the
// single source of truth for an exercise's shape (like CatalogMealDetail does).
struct SessionExerciseWithSets: Decodable, Identifiable, Equatable, Sendable {
  let exercise: SessionExercise
  /// Sorted by `setNumber` at decode time — PostgREST does not order embeds.
  let sets: [SessionSet]

  var id: UUID { exercise.id }
  var sessionId: UUID { exercise.sessionId }
  var workoutId: String? { exercise.workoutId }
  var name: String { exercise.name }
  var position: Int { exercise.position }

  private enum CodingKeys: String, CodingKey {
    case sets = "session_sets"
  }

  init(exercise: SessionExercise, sets: [SessionSet]) {
    self.exercise = exercise
    self.sets = sets
  }

  init(from decoder: Decoder) throws {
    exercise = try SessionExercise(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let embedded = try c.decodeIfPresent([SessionSet].self, forKey: .sets) ?? []
    sets = embedded.sorted { $0.setNumber < $1.setNumber }
  }
}

// The decode target for `select("*, session_exercises(*, session_sets(*))")` —
// a full session with everything logged under it.
struct SessionWithExercises: Decodable, Identifiable, Equatable, Sendable {
  let session: WorkoutSession
  /// Sorted by `position` at decode time.
  let exercises: [SessionExerciseWithSets]

  var id: UUID { session.id }
  var status: SessionStatus { session.status }
  var startedAt: Date { session.startedAt }
  var endedAt: Date? { session.endedAt }
  var durationSeconds: Int? { session.durationSeconds }
  var categoryName: String? { session.categoryName }
  var categorySlug: String? { session.categorySlug }
  var notes: String? { session.notes }

  private enum CodingKeys: String, CodingKey {
    case exercises = "session_exercises"
  }

  init(session: WorkoutSession, exercises: [SessionExerciseWithSets]) {
    self.session = session
    self.exercises = exercises
  }

  init(from decoder: Decoder) throws {
    session = try WorkoutSession(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let embedded = try c.decodeIfPresent([SessionExerciseWithSets].self, forKey: .exercises) ?? []
    exercises = embedded.sorted { $0.position < $1.position }
  }
}

// A completed session plus the two counts the history list shows, from the
// lightweight embed `session_exercises(id, session_sets(id))` — ids only, so a
// 30-day history stays one small response.
struct HistorySession: Decodable, Identifiable, Equatable, Sendable {
  let session: WorkoutSession
  let exerciseCount: Int
  let setCount: Int

  var id: UUID { session.id }
  var startedAt: Date { session.startedAt }
  var endedAt: Date? { session.endedAt }
  var durationSeconds: Int? { session.durationSeconds }
  var categoryName: String? { session.categoryName }
  var categorySlug: String? { session.categorySlug }
  var notes: String? { session.notes }

  private enum CodingKeys: String, CodingKey {
    case exercises = "session_exercises"
  }

  // Only the shape needed to count — one id per exercise, one per set.
  private struct CountedExercise: Decodable {
    let sets: [Identified]?

    enum CodingKeys: String, CodingKey {
      case sets = "session_sets"
    }
  }

  private struct Identified: Decodable {
    let id: UUID
  }

  init(session: WorkoutSession, exerciseCount: Int, setCount: Int) {
    self.session = session
    self.exerciseCount = exerciseCount
    self.setCount = setCount
  }

  init(from decoder: Decoder) throws {
    session = try WorkoutSession(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let counted = try c.decodeIfPresent([CountedExercise].self, forKey: .exercises) ?? []
    exerciseCount = counted.count
    setCount = counted.reduce(0) { $0 + ($1.sets?.count ?? 0) }
  }
}

// MARK: - Timestamp coding

// Shared timestamp handling for the three session tables: encode with fractional
// seconds, decode with a plain-ISO fallback (Postgres drops the fraction when it
// is exactly zero). Same contract as LoggedMeal's private helpers, hoisted to
// file scope because three models need it.
private enum SessionTime {
  static func string(_ date: Date) -> String {
    ISO8601DateFormatter.fuelWithFractional.string(from: date)
  }

  static func parse(_ raw: String) -> Date? {
    ISO8601DateFormatter.fuelWithFractional.date(from: raw)
      ?? ISO8601DateFormatter.fuelPlain.date(from: raw)
  }

  static func required<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> Date {
    let raw = try c.decode(String.self, forKey: key)
    guard let date = parse(raw) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: c,
        debugDescription: "Unrecognized timestamp: \(raw)"
      )
    }
    return date
  }

  static func optional<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> Date? {
    guard let raw = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
    return parse(raw)
  }
}
