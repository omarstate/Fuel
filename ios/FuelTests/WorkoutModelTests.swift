import Testing
import Foundation
@testable import Fuel

// Pins both halves of the workouts data contract: the camelCase catalog shapes
// the Express API returns (decoded with JSONDecoder.fuel()), and the snake_case
// PostgREST session rows (decoded with a PLAIN coder, proving WorkoutSession &
// friends carry their own key names, timestamps and lenient numerics).
//
// Fixtures are shaped exactly like the real responses, including the numeric(6,2)
// weight arriving as a quoted string and embeds coming back out of order.
@Suite("Workout models")
struct WorkoutModelTests {
  private let api = JSONDecoder.fuel()
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  private func decodeAPI<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try api.decode(type, from: Data(json.utf8))
  }

  private func decodeRow<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
  }

  // MARK: - Catalog (Express API)

  @Test("grouped workouts decode as category + its workouts")
  func grouped() throws {
    let json = #"""
    [
      {
        "category": {
          "id": "wc_1",
          "name": "Push",
          "slug": "push",
          "description": "Chest, shoulders, triceps",
          "sortOrder": 1
        },
        "workouts": [
          {
            "id": "w_1",
            "name": "Bench Press",
            "description": "Flat barbell bench",
            "primaryMuscle": "Chest",
            "equipment": "Barbell",
            "targetSets": 4,
            "targetReps": "8-12",
            "categories": [{ "id": "wc_1", "name": "Push", "slug": "push" }],
            "createdAt": "2026-07-10T18:22:05Z"
          }
        ]
      },
      {
        "category": {
          "id": "wc_2",
          "name": "Pull",
          "slug": "pull",
          "description": null,
          "sortOrder": 2
        },
        "workouts": []
      }
    ]
    """#
    let groups = try decodeAPI([GroupedWorkouts].self, json)
    #expect(groups.count == 2)
    #expect(groups[0].category.name == "Push")
    #expect(groups[0].id == "wc_1")  // Identifiable forwards to the category
    #expect(groups[0].workouts.count == 1)

    let bench = groups[0].workouts[0]
    #expect(bench.name == "Bench Press")
    #expect(bench.primaryMuscle == "Chest")
    #expect(bench.targetSets == 4)
    #expect(bench.targetReps == "8-12")  // free-form, stays a string
    #expect(bench.categories.map(\.slug) == ["push"])
    #expect(bench.createdAt != nil)

    // An empty category is a real state, not a decode failure.
    #expect(groups[1].category.description == nil)
    #expect(groups[1].workouts.isEmpty)
  }

  @Test("paginated list decodes with every optional null and createdAt absent")
  func listWithNulls() throws {
    let json = #"""
    {
      "data": [
        {
          "id": "w_9",
          "name": "Air Squat",
          "description": null,
          "primaryMuscle": null,
          "equipment": null,
          "targetSets": null,
          "targetReps": null,
          "categories": []
        }
      ],
      "count": 57
    }
    """#
    struct ListEnvelope: Decodable {
      let data: [Workout]
      let count: Int
    }
    let env = try decodeAPI(ListEnvelope.self, json)
    #expect(env.count == 57)
    #expect(env.data.count == 1)

    let squat = env.data[0]
    #expect(squat.name == "Air Squat")
    #expect(squat.description == nil)
    #expect(squat.primaryMuscle == nil)
    #expect(squat.equipment == nil)
    #expect(squat.targetSets == nil)
    #expect(squat.targetReps == nil)
    #expect(squat.categories.isEmpty)
    #expect(squat.createdAt == nil)  // key missing entirely
  }

  @Test("WorkoutInput omits nil optionals — the zod schema rejects null")
  func inputOmitsNils() throws {
    let input = WorkoutInput(
      name: "Face Pull",
      description: nil,
      categoryIds: ["wc_2"],
      primaryMuscle: nil,
      equipment: nil,
      targetSets: nil,
      targetReps: nil
    )
    let json = String(data: try encoder.encode(input), encoding: .utf8)!
    #expect(json.contains("\"name\""))
    #expect(json.contains("\"categoryIds\""))
    #expect(!json.contains("\"description\""))
    #expect(!json.contains("\"primaryMuscle\""))
    #expect(!json.contains("\"targetSets\""))
  }

  // MARK: - Session rows (PostgREST)

  @Test("a flat workout_sessions row decodes with snake_case keys")
  func flatSessionRow() throws {
    let json = #"""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "category_id": "33333333-3333-3333-3333-333333333333",
      "category_name": "Push",
      "category_slug": "push",
      "status": "in_progress",
      "started_at": "2026-07-19T18:30:00.123Z",
      "ended_at": null,
      "duration_seconds": null,
      "notes": null,
      "created_at": "2026-07-19T18:30:00Z"
    }
    """#
    let session = try decodeRow(WorkoutSession.self, json)
    #expect(session.status == .inProgress)
    #expect(session.categoryName == "Push")
    #expect(session.categorySlug == "push")
    #expect(session.endedAt == nil)
    #expect(session.durationSeconds == nil)
    #expect(session.notes == nil)
    #expect(session.createdAt != nil)  // plain ISO, no fraction — fallback path
    #expect(session.userId.uuidString == "22222222-2222-2222-2222-222222222222")
  }

  @Test("nested embeds sort by position and set_number regardless of arrival order")
  func nestedSortsEmbeds() throws {
    let json = #"""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "category_id": null,
      "category_name": null,
      "category_slug": null,
      "status": "completed",
      "started_at": "2026-07-19T18:30:00.000Z",
      "ended_at": "2026-07-19T19:15:00.000Z",
      "duration_seconds": 2700,
      "notes": "Felt strong",
      "created_at": "2026-07-19T18:30:00.000Z",
      "session_exercises": [
        {
          "id": "aaaaaaaa-0000-0000-0000-000000000002",
          "session_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "workout_id": null,
          "name": "Second",
          "position": 2,
          "created_at": "2026-07-19T18:40:00.000Z",
          "session_sets": []
        },
        {
          "id": "aaaaaaaa-0000-0000-0000-000000000001",
          "session_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "22222222-2222-2222-2222-222222222222",
          "workout_id": "99999999-9999-9999-9999-999999999999",
          "name": "First",
          "position": 1,
          "created_at": "2026-07-19T18:31:00.000Z",
          "session_sets": [
            {
              "id": "bbbbbbbb-0000-0000-0000-000000000003",
              "session_exercise_id": "aaaaaaaa-0000-0000-0000-000000000001",
              "user_id": "22222222-2222-2222-2222-222222222222",
              "set_number": 3,
              "weight": 80,
              "reps": 6,
              "note": null,
              "created_at": "2026-07-19T18:38:00.000Z"
            },
            {
              "id": "bbbbbbbb-0000-0000-0000-000000000001",
              "session_exercise_id": "aaaaaaaa-0000-0000-0000-000000000001",
              "user_id": "22222222-2222-2222-2222-222222222222",
              "set_number": 1,
              "weight": "62.50",
              "reps": 10,
              "note": "warmup",
              "created_at": "2026-07-19T18:32:00.000Z"
            },
            {
              "id": "bbbbbbbb-0000-0000-0000-000000000002",
              "session_exercise_id": "aaaaaaaa-0000-0000-0000-000000000001",
              "user_id": "22222222-2222-2222-2222-222222222222",
              "set_number": 2,
              "weight": 62.5,
              "reps": 8,
              "note": null,
              "created_at": "2026-07-19T18:35:00.000Z"
            }
          ]
        }
      ]
    }
    """#
    let detail = try decodeRow(SessionWithExercises.self, json)
    #expect(detail.status == .completed)
    #expect(detail.durationSeconds == 2700)
    #expect(detail.notes == "Felt strong")
    #expect(detail.exercises.map(\.name) == ["First", "Second"])
    #expect(detail.exercises[0].workoutId == "99999999-9999-9999-9999-999999999999")
    #expect(detail.exercises[1].workoutId == nil)  // custom exercise

    let sets = detail.exercises[0].sets
    #expect(sets.map(\.setNumber) == [1, 2, 3])
    // Same weight, three JSON spellings: quoted numeric, double, int.
    #expect(sets[0].weight == 62.5)  // "62.50"
    #expect(sets[1].weight == 62.5)  // 62.5
    #expect(sets[2].weight == 80)    // 80
    #expect(sets[0].note == "warmup")
    #expect(detail.exercises[1].sets.isEmpty)
  }

  @Test("a set with every optional null decodes as bodyweight")
  func allNullSet() throws {
    let json = #"""
    {
      "id": "bbbbbbbb-0000-0000-0000-000000000009",
      "session_exercise_id": "aaaaaaaa-0000-0000-0000-000000000001",
      "user_id": "22222222-2222-2222-2222-222222222222",
      "set_number": 1,
      "weight": null,
      "reps": null,
      "note": null,
      "created_at": null
    }
    """#
    let set = try decodeRow(SessionSet.self, json)
    #expect(set.setNumber == 1)
    #expect(set.weight == nil)  // null, NOT 0 — the UI shows "BW"
    #expect(set.reps == nil)
    #expect(set.note == nil)
    #expect(set.createdAt == nil)
  }

  @Test("HistorySession counts exercises and sets from the id-only embed")
  func historyCounts() throws {
    let json = #"""
    [
      {
        "id": "11111111-1111-1111-1111-111111111111",
        "user_id": "22222222-2222-2222-2222-222222222222",
        "category_id": null,
        "category_name": "Pull",
        "category_slug": "pull",
        "status": "completed",
        "started_at": "2026-07-19T18:30:00.000Z",
        "ended_at": "2026-07-19T19:15:00.000Z",
        "duration_seconds": 2700,
        "notes": null,
        "created_at": "2026-07-19T18:30:00.000Z",
        "session_exercises": [
          {
            "id": "aaaaaaaa-0000-0000-0000-000000000001",
            "session_sets": [
              { "id": "bbbbbbbb-0000-0000-0000-000000000001" },
              { "id": "bbbbbbbb-0000-0000-0000-000000000002" }
            ]
          },
          {
            "id": "aaaaaaaa-0000-0000-0000-000000000002",
            "session_sets": [
              { "id": "bbbbbbbb-0000-0000-0000-000000000003" }
            ]
          }
        ]
      },
      {
        "id": "44444444-4444-4444-4444-444444444444",
        "user_id": "22222222-2222-2222-2222-222222222222",
        "category_id": null,
        "category_name": null,
        "category_slug": null,
        "status": "completed",
        "started_at": "2026-07-12T09:00:00.000Z",
        "ended_at": "2026-07-12T09:30:00.000Z",
        "duration_seconds": 1800,
        "notes": null,
        "created_at": "2026-07-12T09:00:00.000Z",
        "session_exercises": []
      }
    ]
    """#
    let history = try decodeRow([HistorySession].self, json)
    #expect(history.count == 2)
    #expect(history[0].exerciseCount == 2)
    #expect(history[0].setCount == 3)
    #expect(history[0].categoryName == "Pull")
    #expect(history[0].durationSeconds == 2700)
    // An empty session still decodes, with honest zeroes.
    #expect(history[1].exerciseCount == 0)
    #expect(history[1].setCount == 0)
  }

  // MARK: - Encoding (insert bodies)

  @Test("WorkoutSession encodes snake_case, an ISO started_at, and no created_at")
  func encodesSession() throws {
    let session = WorkoutSession(
      id: UUID(),
      userId: UUID(),
      categoryId: "wc_1",
      categoryName: "Push",
      categorySlug: "push",
      startedAt: TestCal.date(2026, 7, 19, 18, 30)
    )
    let json = String(data: try encoder.encode(session), encoding: .utf8)!
    #expect(json.contains("\"user_id\""))
    #expect(json.contains("\"category_slug\""))
    #expect(json.contains("\"started_at\":\"2026-07-19T18:30:00.000Z\""))
    #expect(json.contains("\"status\":\"in_progress\""))
    #expect(json.contains("\"ended_at\""))        // present, encoded as null
    #expect(json.contains("\"duration_seconds\""))
    #expect(!json.contains("created_at"))         // DB default wins
  }

  @Test("SessionExercise and SessionSet encode snake_case without created_at")
  func encodesExerciseAndSet() throws {
    let exerciseJSON = String(
      data: try encoder.encode(
        SessionExercise(sessionId: UUID(), userId: UUID(), workoutId: nil, name: "Row", position: 1)
      ),
      encoding: .utf8
    )!
    #expect(exerciseJSON.contains("\"session_id\""))
    #expect(exerciseJSON.contains("\"workout_id\""))  // explicit null = custom
    #expect(!exerciseJSON.contains("created_at"))

    let setJSON = String(
      data: try encoder.encode(
        SessionSet(sessionExerciseId: UUID(), userId: UUID(), setNumber: 2, weight: 62.5, reps: 8)
      ),
      encoding: .utf8
    )!
    #expect(setJSON.contains("\"session_exercise_id\""))
    #expect(setJSON.contains("\"set_number\":2"))
    #expect(setJSON.contains("\"note\""))            // present, encoded as null
    #expect(!setJSON.contains("created_at"))
  }

  @Test("a session row round-trips through encode → decode")
  func sessionRoundTrip() throws {
    let original = WorkoutSession(
      id: UUID(),
      userId: UUID(),
      categoryId: "wc_1",
      categoryName: "Legs",
      categorySlug: "legs",
      status: .completed,
      startedAt: TestCal.date(2026, 7, 19, 18, 30),
      endedAt: TestCal.date(2026, 7, 19, 19, 15),
      durationSeconds: 2700,
      notes: "Solid"
    )
    let decoded = try decodeRow(WorkoutSession.self, String(data: try encoder.encode(original), encoding: .utf8)!)
    #expect(decoded == original)
  }
}
