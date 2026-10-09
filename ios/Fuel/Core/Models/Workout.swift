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
  /// RELATIVE dataset paths, carried over when the workout was added from the
  /// exercise catalog (empty for a hand-written one). Use `imageURLs` — never
  /// build the prefix at a call site.
  ///
  /// `var` with a default so the memberwise init stays callable without them;
  /// decoding tolerance is separate (see the `init(from:)` below) because
  /// synthesized Decodable ignores property defaults.
  var images: [String] = []
  /// The dataset's numbered how-to, verbatim. `description` is a 240-char
  /// squeeze of the first step or two, so a detail view showing both would
  /// repeat itself — show the description only when this is empty.
  var instructions: [String] = []
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

extension Workout {
  /// Every demo photo, in dataset order — shared with `CatalogExercise` so a
  /// browsed exercise and the library card it becomes resolve identically.
  var imageURLs: [URL] { ExerciseImages.urls(images) }

  /// "4 × 8-12", or whichever half exists. Port of `setsReps` in
  /// workouts/workout-card.tsx — targetReps is free-form ("AMRAP"), so it is
  /// never parsed, only shown.
  var targetText: String? {
    if let sets = targetSets, let reps = targetReps, !reps.isEmpty {
      return "\(sets) × \(reps)"
    }
    if let reps = targetReps, !reps.isEmpty { return reps }
    if let sets = targetSets { return String(localized: "\(sets) sets") }
    return nil
  }

  /// "Chest · Barbell" — the card eyebrow, and the shape `CatalogExercise`
  /// uses, so a browsed row and the card it becomes read identically.
  var metaLine: String? {
    let parts = [primaryMuscle, equipment]
      .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// The dataset's `description` is a 240-char squeeze of the first instruction
  /// step or two, so showing both on one screen repeats itself. Detail views
  /// fall back to it only when there are no steps to show.
  var standaloneDescription: String? {
    guard instructions.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
      return nil
    }
    let text = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (text?.isEmpty ?? true) ? nil : text
  }
}

// Decoding lives in an extension on purpose: a custom init inside the struct
// body would suppress the memberwise init that previews, tests and the
// placeholder card all use.
//
// `images`/`instructions` are decodeIfPresent because migration 0014 may not
// have run on the deployed database — the backend then omits nothing (it maps
// a missing column to []), but a response from an OLDER backend build has no
// such key at all, and one missing array must not fail a whole list decode.
extension Workout {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    primaryMuscle = try container.decodeIfPresent(String.self, forKey: .primaryMuscle)
    equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
    targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets)
    targetReps = try container.decodeIfPresent(String.self, forKey: .targetReps)
    images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
    instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
    categories = try container.decodeIfPresent([CategoryRef].self, forKey: .categories) ?? []
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
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
