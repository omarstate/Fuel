import Foundation

// One row of the mirrored free-exercise-db dataset, served by
// GET /workouts/exercise-catalog. Mirrors backend/src/models/exercise.model.js
// (`rowToExercise`) field for field.
//
// This is NOT a `Workout`. It is the *source* you browse; adding one copies it
// into the curated workout catalog, which is what `Workout` represents.
struct CatalogExercise: Codable, Identifiable, Hashable, Sendable {
  /// The dataset's own id ("3_4_Sit-Up") — the add endpoint's path param, and a
  /// stabler identity for the list than the row uuid.
  let slug: String
  let name: String
  /// strength | stretching | plyometrics | strongman | powerlifting | cardio |
  /// olympic weightlifting. Free text by design: the backend stores whatever
  /// the dataset ships, so never switch exhaustively over it.
  let category: String
  let level: String?
  let mechanic: String?
  let force: String?
  let equipment: String?
  /// Lowercase dataset spellings ("lower back"); title-cased for display.
  let primaryMuscles: [String]
  let secondaryMuscles: [String]
  let instructions: [String]
  /// RELATIVE paths inside the dataset repo. Use `imageURL` — never build the
  /// prefix at a call site.
  let images: [String]
  /// True when a workout with this name is already in the curated catalog. The
  /// backend computes it per page; absent (nil) means "not computed", which the
  /// UI treats as addable.
  let inLibrary: Bool?

  var id: String { slug }

  /// Demo photo for the row thumbnail, or nil when the dataset has none (3 of
  /// ~870 entries ship without images).
  var imageURL: URL? {
    guard let path = images.first, !path.isEmpty else { return nil }
    return URL(string: Self.imagePrefix + path)
  }

  private static let imagePrefix =
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

  /// "Chest · Barbell · Beginner" — whichever parts exist, title-cased the same
  /// way the backend title-cases them on the way into `workouts`, so a row and
  /// the card it becomes read identically.
  var metaLine: String? {
    let parts = [primaryMuscles.first, equipment, level]
      .compactMap { $0 }
      .map(CatalogExercise.titleCased)
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// "lower back" -> "Lower Back", "e-z curl bar" -> "E-Z Curl Bar".
  static func titleCased(_ value: String) -> String {
    var out = ""
    var atBoundary = true
    for character in value {
      if atBoundary, character.isLetter {
        out.append(contentsOf: String(character).uppercased())
        atBoundary = false
      } else {
        out.append(character)
        if !character.isLetter && !character.isNumber { atBoundary = true }
      }
    }
    return out
  }
}

// POST /workouts/exercise-catalog/:slug/add -> the curated Workout plus whether
// it was inserted now (`created: true`) or already there (`created: false`).
struct AddExerciseResult: Decodable, Sendable {
  let workout: Workout
  let created: Bool
}

// POST /workouts/exercise-catalog/import (admin) -> import counters.
struct ExerciseImportResult: Decodable, Sendable {
  let imported: Int
  let total: Int
  let skipped: Int?
}
