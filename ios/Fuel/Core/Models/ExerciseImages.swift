import Foundation

// Where the exercise demo photos live.
//
// Both `exercise_catalog` rows and the `workouts` they are copied into store
// RELATIVE paths ("Bench_Press/0.jpg") rather than absolute URLs, so moving the
// images never needs a re-import or a backfill. That makes the prefix a client
// concern — and a single one: `CatalogExercise` and `Workout` both resolve
// through here so a browsed exercise and the library card it becomes can never
// disagree about where its photos are.
enum ExerciseImages {
  static let prefix = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

  /// Relative dataset paths -> absolute URLs, in order. The dataset ships 0, 1
  /// or 2 photos per exercise — frame 0 is the start of the movement and frame
  /// 1 the end, which is what lets a detail view alternate between them to
  /// imply motion. Empty and unparseable paths drop out rather than producing a
  /// broken frame.
  static func urls(_ paths: [String]) -> [URL] {
    paths.compactMap { path in
      guard !path.isEmpty else { return nil }
      return URL(string: prefix + path)
    }
  }
}
