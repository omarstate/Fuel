import Foundation

// POST /ai/workouts/voice-log — a spoken set report in, editable exercises + sets
// out. You say "بنش برس تمانين في تمانية، وبعدين خمسة وتمانين في ستة" between
// sets and one ungrounded Gemini call turns it into rows you confirm with a
// thumb, instead of typing two numbers per set with chalk on your hands.
//
// `kind` is the discriminator and decides where the sets land: "session" already
// has a row in THIS workout (carries its `sessionExerciseId`), "catalog" is in
// the shared exercise library (carries the full `workout`), "custom" is neither
// and gets a new session row — plus an optional catalog entry if the user opts
// in. An unknown kind degrades to "custom", which is the shape that needs no
// server-side identity to work.
//
// Numerics decode leniently (Double, Int or a quoted string) exactly like
// VoiceLog.swift's estimates: the values originate from a language model, and a
// weight arriving as "80.00" must not fail an entire response. `VoiceConfidence`
// is shared with the meal flow rather than redeclared.

// One exercise already logged in the live session, sent as a hint. Without these
// the model cannot resolve "كمان سِت" / "same weight, two more reps" — and it
// would invent a second "Bench Press" row instead of appending to the one on
// screen.
struct VoiceSessionExerciseHint: Encodable, Equatable, Sendable {
  let id: UUID
  let name: String
  let workoutId: String?
  let setCount: Int
  let lastWeight: Double?
  let lastReps: Int?

  init(id: UUID, name: String, workoutId: String?, setCount: Int, lastWeight: Double?, lastReps: Int?) {
    self.id = id
    self.name = name
    self.workoutId = workoutId
    self.setCount = setCount
    self.lastWeight = lastWeight
    self.lastReps = lastReps
  }

  /// Straight mapping off a live session row — the last set is what "same
  /// weight" refers to.
  init(_ entry: SessionExerciseWithSets) {
    self.init(
      id: entry.id,
      name: entry.name,
      workoutId: entry.workoutId,
      setCount: entry.sets.count,
      lastWeight: entry.sets.last?.weight,
      lastReps: entry.sets.last?.reps
    )
  }
}

struct VoiceSetLogBody: Encodable, Sendable {
  let transcript: String
  let lang: String
  /// Always "kg" today — the app has no imperial mode, but the field is on the
  /// wire so adding one is a client-only change.
  let unit: String
  let sessionExercises: [VoiceSessionExerciseHint]
}

// One set the model heard. `weight` nil means bodyweight (never zero — they are
// different things), `reps` nil means the user only said a weight.
struct VoiceParsedSet: Decodable, Equatable, Sendable {
  let setNumber: Int?
  let weight: Double?
  let reps: Int?
  let note: String?

  private enum CodingKeys: String, CodingKey {
    case setNumber, weight, reps, note
  }

  init(setNumber: Int?, weight: Double?, reps: Int?, note: String?) {
    self.setNumber = setNumber
    self.weight = weight
    self.reps = reps
    self.note = note
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    setNumber = Self.lenientInt(c, .setNumber)
    weight = Self.lenientDouble(c, .weight)
    reps = Self.lenientInt(c, .reps)
    note = try? c.decodeIfPresent(String.self, forKey: .note)
  }

  // Double, Int or a quoted machine string ("80.00"). The string is JSON, not
  // user input, so it parses with the POSIX `Double(_:)` — never NumberParsing.
  private static func lenientDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
    return nil
  }

  private static func lenientInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d.rounded()) }
    if let s = try? c.decodeIfPresent(String.self, forKey: key), let d = Double(s) { return Int(d.rounded()) }
    return nil
  }
}

enum VoiceExerciseKind: String, Decodable, Sendable {
  /// Already a row in the session on screen.
  case session
  /// In the shared exercise catalog, but not yet in this session.
  case catalog
  /// Neither — a brand new name.
  case custom
}

struct VoiceParsedExercise: Decodable, Equatable, Sendable {
  let kind: VoiceExerciseKind
  /// The words the user actually said for this exercise, amounts included.
  let spoken: String
  let name: String
  let nameAr: String?
  /// True when the exercise carries no external load (pull-ups, dips) — the set
  /// rows then read "Bodyweight" instead of showing an empty weight field.
  let bodyweight: Bool
  let confidence: VoiceConfidence?
  /// The `session_exercises` row to append to, for `.session` matches.
  let sessionExerciseId: UUID?
  /// The catalog entry behind a `.catalog` match, same shape as GET /workouts/:id.
  let workout: Workout?
  let sets: [VoiceParsedSet]

  private enum CodingKeys: String, CodingKey {
    case kind, spoken, name, nameAr, bodyweight, confidence, sessionExerciseId, workout, sets
  }

  init(
    kind: VoiceExerciseKind, spoken: String, name: String, nameAr: String?, bodyweight: Bool,
    confidence: VoiceConfidence?, sessionExerciseId: UUID?, workout: Workout?, sets: [VoiceParsedSet]
  ) {
    self.kind = kind
    self.spoken = spoken
    self.name = name
    self.nameAr = nameAr
    self.bodyweight = bodyweight
    self.confidence = confidence
    self.sessionExerciseId = sessionExerciseId
    self.workout = workout
    self.sets = sets
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // An unknown future kind degrades to `.custom`: the one shape that needs no
    // server-side identity, so the row stays loggable instead of failing.
    let rawKind = try? c.decodeIfPresent(String.self, forKey: .kind)
    kind = rawKind.flatMap(VoiceExerciseKind.init(rawValue:)) ?? .custom
    spoken = try c.decodeIfPresent(String.self, forKey: .spoken) ?? ""
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    nameAr = try? c.decodeIfPresent(String.self, forKey: .nameAr)
    bodyweight = (try? c.decodeIfPresent(Bool.self, forKey: .bodyweight)) ?? false
    confidence = try? c.decodeIfPresent(VoiceConfidence.self, forKey: .confidence)
    // A non-UUID string is treated as "no match" rather than a decode failure.
    let rawId = try? c.decodeIfPresent(String.self, forKey: .sessionExerciseId)
    sessionExerciseId = rawId.flatMap(UUID.init(uuidString:))
    workout = try? c.decodeIfPresent(Workout.self, forKey: .workout)
    sets = try c.decodeIfPresent([VoiceParsedSet].self, forKey: .sets) ?? []
  }
}

struct VoiceSetLogResponse: Decodable, Equatable, Sendable {
  let exercises: [VoiceParsedExercise]

  private enum CodingKeys: String, CodingKey { case exercises }

  init(exercises: [VoiceParsedExercise]) {
    self.exercises = exercises
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    exercises = try c.decodeIfPresent([VoiceParsedExercise].self, forKey: .exercises) ?? []
  }
}

// MARK: - Commit (catalog side only)

// POST /ai/workouts/voice-log/commit — teaches the shared catalog what this
// utterance revealed: the phrase the user said as an alias on a matched workout,
// and brand new exercises they chose to keep. Best-effort by design; the sets go
// to Supabase either way.
struct VoiceWorkoutAliasUpdate: Encodable, Equatable, Sendable {
  let workoutId: String
  let aliases: [String]
}

struct VoiceNewWorkoutInput: Encodable, Equatable, Sendable {
  let name: String
  let primaryMuscle: String?
  let equipment: String?
  let aliases: [String]
}

struct VoiceWorkoutCommitBody: Encodable, Sendable {
  let aliasUpdates: [VoiceWorkoutAliasUpdate]
  let newWorkouts: [VoiceNewWorkoutInput]
}

struct VoiceWorkoutCommitResponse: Decodable, Equatable, Sendable {
  let workouts: [Created]
  let aliasesUpdated: Int

  // `name` echoes the request so the app can map a created workout back to the
  // review row that produced it.
  struct Created: Decodable, Equatable, Sendable {
    let name: String
    let workout: Workout
  }

  private enum CodingKeys: String, CodingKey { case workouts, aliasesUpdated }

  init(workouts: [Created], aliasesUpdated: Int) {
    self.workouts = workouts
    self.aliasesUpdated = aliasesUpdated
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    workouts = try c.decodeIfPresent([Created].self, forKey: .workouts) ?? []
    aliasesUpdated = (try? c.decodeIfPresent(Int.self, forKey: .aliasesUpdated)) ?? 0
  }

  /// The workout created for `name`, matched case-insensitively — the mirror of
  /// `VoiceCommitResponse.catalogId(for:)` on the meals side.
  func createdWorkout(named name: String) -> Workout? {
    let key = name.lowercased()
    return workouts.first { $0.name.lowercased() == key }?.workout
  }
}
