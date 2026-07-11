// snake_case (DB row, optionally with a joined `workout_categories` relation
// via the workout_category_map many-to-many) -> camelCase (API response)
export const rowToWorkout = (row) => {
  const categories = Array.isArray(row.workout_categories) ? row.workout_categories : []

  return {
    id: row.id,
    name: row.name,
    description: row.description,
    primaryMuscle: row.primary_muscle,
    equipment: row.equipment,
    targetSets: row.target_sets,
    targetReps: row.target_reps,
    categories: categories.map((c) => ({ id: c.id, name: c.name, slug: c.slug })),
    createdAt: row.created_at,
  }
}

// camelCase (API request DTO) -> snake_case (DB insert row)
// NOTE: dto.categoryIds is handled separately via workout_category_map, not a
// column on workouts, so it's intentionally excluded here.
export const dtoToRow = (dto) => ({
  name: dto.name,
  description: dto.description ?? null,
  primary_muscle: dto.primaryMuscle ?? null,
  equipment: dto.equipment ?? null,
  target_sets: dto.targetSets ?? null,
  target_reps: dto.targetReps ?? null,
})
