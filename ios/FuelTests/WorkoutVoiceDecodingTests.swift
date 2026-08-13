import Testing
import Foundation
@testable import Fuel

// Pins the POST /ai/workouts/voice-log contract the app decodes: exercises are
// discriminated by `kind` ("session" already has a row in this workout, "catalog"
// is in the shared library, "custom" is neither), an unknown kind degrades to
// custom rather than failing the response, weights arrive as ints, doubles OR
// quoted strings from the model, a bodyweight set carries a null weight (which is
// not zero), and the commit response echoes each input name so a created workout
// can be mapped back to the review row that produced it.
@Suite("Workout voice decoding")
struct WorkoutVoiceDecodingTests {
  private let decoder = JSONDecoder.fuel()

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  // MARK: - kind discrimination

  @Test("A session match carries the row to append to")
  func sessionMatch() throws {
    let json = #"""
    {
      "exercises": [
        {
          "kind": "session",
          "spoken": "كمان سِت تمانين في ستة",
          "name": "Barbell Bench Press",
          "nameAr": "بنش برس",
          "bodyweight": false,
          "confidence": "high",
          "sessionExerciseId": "11111111-2222-3333-4444-555555555555",
          "workout": null,
          "sets": [{ "setNumber": 3, "weight": 80, "reps": 6, "note": null }]
        }
      ]
    }
    """#
    let response = try decode(VoiceSetLogResponse.self, json)
    #expect(response.exercises.count == 1)

    let exercise = response.exercises[0]
    #expect(exercise.kind == .session)
    #expect(exercise.name == "Barbell Bench Press")
    #expect(exercise.nameAr == "بنش برس")
    #expect(exercise.confidence == .high)
    #expect(exercise.workout == nil)
    #expect(exercise.sessionExerciseId == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
    #expect(exercise.sets.count == 1)
    #expect(exercise.sets[0].setNumber == 3)
    #expect(exercise.sets[0].weight == 80)
    #expect(exercise.sets[0].reps == 6)
    #expect(exercise.sets[0].note == nil)
  }

  @Test("A catalog match carries the full workout")
  func catalogMatch() throws {
    let json = #"""
    {
      "exercises": [
        {
          "kind": "catalog",
          "spoken": "lat pulldown 60 for 12",
          "name": "Lat Pulldown",
          "nameAr": null,
          "bodyweight": false,
          "confidence": "medium",
          "sessionExerciseId": null,
          "workout": {
            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "name": "Lat Pulldown",
            "description": "Cable pulldown to the chest.",
            "primaryMuscle": "Lats",
            "equipment": "Cable",
            "targetSets": 4,
            "targetReps": "8-12",
            "categories": [{ "id": "c_1", "name": "Pull", "slug": "pull" }],
            "createdAt": "2026-02-01T09:00:00Z"
          },
          "sets": [{ "setNumber": 1, "weight": 60, "reps": 12, "note": null }]
        }
      ]
    }
    """#
    let exercise = try decode(VoiceSetLogResponse.self, json).exercises[0]
    #expect(exercise.kind == .catalog)
    #expect(exercise.sessionExerciseId == nil)
    #expect(exercise.workout?.id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    #expect(exercise.workout?.primaryMuscle == "Lats")
    #expect(exercise.workout?.targetReps == "8-12")   // free-form, never a number
    #expect(exercise.workout?.categories.first?.slug == "pull")
  }

  @Test("An unknown kind degrades to custom instead of failing the response")
  func unknownKind() throws {
    let json = #"""
    {
      "exercises": [
        { "kind": "superset", "spoken": "zercher squat 60 for 5", "name": "Zercher Squat",
          "bodyweight": false, "sets": [{ "weight": 60, "reps": 5 }] },
        { "spoken": "sled push", "name": "Sled Push", "sets": [] }
      ]
    }
    """#
    let response = try decode(VoiceSetLogResponse.self, json)
    #expect(response.exercises.count == 2)
    #expect(response.exercises[0].kind == .custom)   // unrecognised string
    #expect(response.exercises[1].kind == .custom)   // key missing entirely
    #expect(response.exercises[1].bodyweight == false)
    #expect(response.exercises[1].sets.isEmpty)
  }

  @Test("An empty response decodes to no exercises")
  func emptyResponse() throws {
    #expect(try decode(VoiceSetLogResponse.self, #"{ "exercises": [] }"#).exercises.isEmpty)
    #expect(try decode(VoiceSetLogResponse.self, #"{}"#).exercises.isEmpty)
  }

  @Test("A non-UUID session id is treated as no match, not a decode failure")
  func malformedSessionId() throws {
    let json = #"""
    { "exercises": [
      { "kind": "session", "spoken": "bench", "name": "Bench", "sessionExerciseId": "not-a-uuid", "sets": [] }
    ] }
    """#
    #expect(try decode(VoiceSetLogResponse.self, json).exercises[0].sessionExerciseId == nil)
  }

  // MARK: - Lenient numerics

  @Test("Weight decodes from an int, a double or a quoted string")
  func lenientWeights() throws {
    let json = #"""
    { "exercises": [
      { "kind": "custom", "spoken": "x", "name": "X", "sets": [
        { "setNumber": 1, "weight": 80, "reps": 8 },
        { "setNumber": 2, "weight": 80.5, "reps": 8 },
        { "setNumber": 3, "weight": "80.00", "reps": "8" }
      ] }
    ] }
    """#
    let sets = try decode(VoiceSetLogResponse.self, json).exercises[0].sets
    #expect(sets[0].weight == 80)
    #expect(sets[1].weight == 80.5)
    #expect(sets[2].weight == 80)
    #expect(sets[2].reps == 8)      // strings on the rep side too
  }

  @Test("A bodyweight set has a null weight — which is not zero")
  func bodyweightSet() throws {
    let json = #"""
    { "exercises": [
      { "kind": "catalog", "spoken": "pull-ups 12 then 10", "name": "Pull-Up", "bodyweight": true,
        "sets": [
          { "setNumber": 1, "weight": null, "reps": 12 },
          { "setNumber": 2, "weight": null, "reps": 10, "note": "slow negatives" }
        ] }
    ] }
    """#
    let exercise = try decode(VoiceSetLogResponse.self, json).exercises[0]
    #expect(exercise.bodyweight)
    #expect(exercise.sets[0].weight == nil)
    #expect(exercise.sets[0].reps == 12)
    #expect(exercise.sets[1].note == "slow negatives")
  }

  @Test("A weight with no reps keeps the weight and leaves reps nil")
  func nullReps() throws {
    let json = #"""
    { "exercises": [
      { "kind": "custom", "spoken": "farmer carry 40", "name": "Farmer Carry",
        "confidence": null, "sets": [{ "weight": 40, "reps": null }] }
    ] }
    """#
    let exercise = try decode(VoiceSetLogResponse.self, json).exercises[0]
    #expect(exercise.confidence == nil)
    #expect(exercise.sets[0].weight == 40)
    #expect(exercise.sets[0].reps == nil)
    #expect(exercise.sets[0].setNumber == nil)
  }

  // MARK: - Commit

  @Test("Commit response maps echoed names back to created workouts")
  func commitResponse() throws {
    let json = #"""
    {
      "workouts": [
        {
          "name": "Zercher Squat",
          "workout": {
            "id": "99999999-8888-7777-6666-555555555555",
            "name": "Zercher Squat",
            "description": null,
            "primaryMuscle": "Quads",
            "equipment": "Barbell",
            "targetSets": null,
            "targetReps": null,
            "categories": [{ "id": "c_2", "name": "Legs", "slug": "legs" }],
            "createdAt": "2026-08-12T09:15:00.123Z"
          }
        }
      ],
      "aliasesUpdated": 2
    }
    """#
    let response = try decode(VoiceWorkoutCommitResponse.self, json)
    #expect(response.aliasesUpdated == 2)
    #expect(response.workouts.count == 1)
    #expect(response.createdWorkout(named: "Zercher Squat")?.id == "99999999-8888-7777-6666-555555555555")
    #expect(response.createdWorkout(named: "zercher squat")?.id == "99999999-8888-7777-6666-555555555555")
    #expect(response.createdWorkout(named: "Sled Push") == nil)
    #expect(response.createdWorkout(named: "Zercher Squat")?.primaryMuscle == "Quads")
  }

  @Test("An empty commit response decodes to zeros")
  func emptyCommitResponse() throws {
    let response = try decode(VoiceWorkoutCommitResponse.self, #"{ "workouts": [], "aliasesUpdated": 0 }"#)
    #expect(response.workouts.isEmpty)
    #expect(response.aliasesUpdated == 0)
  }

  // MARK: - Request side

  @Test("Session hints carry the last set, which is what \"same weight\" means")
  func hintFromSessionRow() {
    let sessionID = UUID()
    let userID = UUID()
    let exerciseID = UUID()
    let entry = SessionExerciseWithSets(
      exercise: SessionExercise(
        id: exerciseID, sessionId: sessionID, userId: userID,
        workoutId: "w1", name: "Bench Press", position: 0
      ),
      sets: [
        SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: 80, reps: 8),
        SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 85, reps: 6),
      ]
    )
    let hint = VoiceSessionExerciseHint(entry)
    #expect(hint.id == exerciseID)
    #expect(hint.name == "Bench Press")
    #expect(hint.workoutId == "w1")
    #expect(hint.setCount == 2)
    #expect(hint.lastWeight == 85)
    #expect(hint.lastReps == 6)
  }

  @Test("An exercise with no sets yet hints nothing to copy")
  func hintWithoutSets() {
    let sessionID = UUID()
    let userID = UUID()
    let entry = SessionExerciseWithSets(
      exercise: SessionExercise(
        sessionId: sessionID, userId: userID, workoutId: nil, name: "Cable Fly", position: 1
      ),
      sets: []
    )
    let hint = VoiceSessionExerciseHint(entry)
    #expect(hint.workoutId == nil)
    #expect(hint.setCount == 0)
    #expect(hint.lastWeight == nil)
    #expect(hint.lastReps == nil)
  }
}
