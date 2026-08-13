import Foundation

// The shared exercise catalog, served by the Express API (camelCase inside a
// `{ data }` envelope, decoded by JSONDecoder.fuel()). These mirror
// backend/src/models/workout.model.js (`rowToWorkout`) and
// workout-category.model.js (`rowToWorkoutCategory`) field for field.
struct WorkoutCategory: Codable, Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let slug: String
  let description: String?
  let sortOrder: Int
}

struct Workout: Codable, Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let description: String?
  let primaryMuscle: String?
  let equipment: String?
  let targetSets: Int?
  // Free-form by design ("8-12", "AMRAP", "to failure") — never parse as a number.
  let targetReps: String?
  let categories: [CategoryRef]
  // Optional purely for tolerance: every current route includes it, but one
  // missing timestamp should not fail an entire list decode.
  let createdAt: Date?

  // A workout belongs to MANY categories (through workout_category_map), so the
  // PostgREST embed resolves to an array of these lightweight refs — unlike
  // CatalogMeal, which carries a single optional CategoryRef.
  struct CategoryRef: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
  }
}

// One element of GET /workouts/grouped: every category in `sortOrder`, each
// with the workouts filed under it. A workout with several categories appears
// under each of them, and a category with none comes back with an empty array.
struct GroupedWorkouts: Codable, Identifiable, Sendable {
  let category: WorkoutCategory
  let workouts: [Workout]

  var id: String { category.id }
}

// POST /workouts body. Matches createWorkoutSchema in
// backend/src/validators/workouts.validator.js, where every optional is
// `.optional()` (undefined) and NOT nullable — so nil must be omitted, which is
// exactly what the synthesized encoder does (it uses encodeIfPresent).
// `categoryIds` is required and must hold at least one uuid.
struct WorkoutInput: Encodable, Sendable {
  let name: String
  let description: String?
  let categoryIds: [String]
  let primaryMuscle: String?
  let equipment: String?
  let targetSets: Int?
  let targetReps: String?
}
