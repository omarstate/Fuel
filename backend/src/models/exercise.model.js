// snake_case (exercise_catalog row) -> camelCase (API response).
//
// `images` stays RELATIVE ("Bench_Press/0.jpg") exactly as the dataset ships
// it; clients join it onto the raw.githubusercontent.com prefix themselves, so
// moving the images elsewhere never needs a re-import.
const toArray = (value) => (Array.isArray(value) ? value : [])

export const rowToExercise = (row) => ({
  id: row.id,
  slug: row.slug,
  name: row.name,
  category: row.category,
  level: row.level,
  mechanic: row.mechanic,
  force: row.force,
  equipment: row.equipment,
  primaryMuscles: toArray(row.primary_muscles),
  secondaryMuscles: toArray(row.secondary_muscles),
  instructions: toArray(row.instructions),
  images: toArray(row.images),
  // Set by listExercises when a `workouts` row with the same name already
  // exists, so the picker can render "In library" instead of an Add button.
  // Absent on routes that don't compute it.
  ...(row.in_library === undefined ? {} : { inLibrary: Boolean(row.in_library) }),
})
