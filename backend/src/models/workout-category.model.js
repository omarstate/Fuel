// snake_case (DB row) -> camelCase (API response)
export const rowToWorkoutCategory = (row) => ({
  id: row.id,
  name: row.name,
  slug: row.slug,
  description: row.description,
  sortOrder: row.sort_order,
})
