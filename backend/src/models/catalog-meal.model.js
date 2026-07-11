// snake_case (DB row, optionally with a joined `meal_categories` relation) ->
// camelCase (API response)
export const rowToCatalogMeal = (row) => {
  const joinedCategory = Array.isArray(row.meal_categories)
    ? row.meal_categories[0]
    : row.meal_categories

  return {
    id: row.id,
    name: row.name,
    description: row.description,
    servingSize: row.serving_size,
    calories: row.calories,
    protein: row.protein,
    carbs: row.carbs,
    fat: row.fat,
    category: joinedCategory
      ? { id: joinedCategory.id, name: joinedCategory.name, slug: joinedCategory.slug }
      : null,
    createdBy: row.created_by,
    createdAt: row.created_at,
  }
}

// Extends a mapped CatalogMeal with the extra `creator` and `stats` fields
// used by the meal detail view (GET /api/meals/:id only).
export const toCatalogMealDetail = (meal, { creator, stats }) => ({
  ...meal,
  creator,
  stats,
})

// camelCase (API request DTO) -> snake_case (DB insert row)
export const dtoToRow = (dto) => ({
  name: dto.name,
  description: dto.description ?? null,
  category_id: dto.categoryId,
  serving_size: dto.servingSize ?? null,
  calories: dto.calories,
  protein: dto.protein,
  carbs: dto.carbs,
  fat: dto.fat,
})

// camelCase (partial API request DTO) -> snake_case (DB update row). Unlike
// dtoToRow, only fields actually present in the DTO are included, so an
// omitted field is left untouched in the database rather than nulled/zeroed.
export const dtoToUpdateRow = (dto) => {
  const row = {}
  if (dto.name !== undefined) row.name = dto.name
  if (dto.description !== undefined) row.description = dto.description
  if (dto.categoryId !== undefined) row.category_id = dto.categoryId
  if (dto.servingSize !== undefined) row.serving_size = dto.servingSize
  if (dto.calories !== undefined) row.calories = dto.calories
  if (dto.protein !== undefined) row.protein = dto.protein
  if (dto.carbs !== undefined) row.carbs = dto.carbs
  if (dto.fat !== undefined) row.fat = dto.fat
  return row
}
