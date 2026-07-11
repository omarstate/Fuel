import { supabase } from "../config/supabase.js"
import { rowToWorkout, dtoToRow } from "../models/workout.model.js"
import { rowToWorkoutCategory } from "../models/workout-category.model.js"
import { ApiError } from "../utils/api-error.js"

// workout_categories is a M2M relation through workout_category_map — the
// PostgREST embed syntax is identical to a simple FK relation, but it
// resolves to an ARRAY on each workout row instead of a single object.
const SELECT_WITH_CATEGORIES = "*, workout_categories(id, name, slug)"
const DEFAULT_LIMIT = 100

export const listWorkouts = async ({ category, search, limit, offset } = {}) => {
  const useInnerJoin = Boolean(category)
  let query = supabase
    .from("workouts")
    .select(
      useInnerJoin ? "*, workout_categories!inner(id, name, slug)" : SELECT_WITH_CATEGORIES,
      { count: "exact" }
    )
    .order("created_at", { ascending: false })

  if (category) {
    query = query.eq("workout_categories.slug", category)
  }

  if (search) {
    query = query.ilike("name", `%${search}%`)
  }

  const safeLimit = limit && limit > 0 ? limit : DEFAULT_LIMIT
  const safeOffset = offset && offset > 0 ? offset : 0
  query = query.range(safeOffset, safeOffset + safeLimit - 1)

  const { data, error, count } = await query

  if (error) throw ApiError.badRequest("Failed to load workouts", error.message)

  return { data: data.map(rowToWorkout), count: count ?? data.length }
}

export const listWorkoutsGrouped = async () => {
  const { data: categoryRows, error: categoryError } = await supabase
    .from("workout_categories")
    .select("*")
    .order("sort_order", { ascending: true })

  if (categoryError) {
    throw ApiError.badRequest("Failed to load workout categories", categoryError.message)
  }

  const { data: workoutRows, error: workoutError } = await supabase
    .from("workouts")
    .select(SELECT_WITH_CATEGORIES)
    .order("created_at", { ascending: false })

  if (workoutError) throw ApiError.badRequest("Failed to load workouts", workoutError.message)

  const workouts = workoutRows.map(rowToWorkout)

  // A workout with multiple categories correctly appears under each of them.
  return categoryRows.map((categoryRow) => {
    const category = rowToWorkoutCategory(categoryRow)
    return {
      category,
      workouts: workouts.filter((workout) => workout.categories.some((c) => c.id === category.id)),
    }
  })
}

export const getWorkoutById = async (id) => {
  const { data, error } = await supabase
    .from("workouts")
    .select(SELECT_WITH_CATEGORIES)
    .eq("id", id)
    .maybeSingle()

  if (error) throw ApiError.badRequest("Failed to load workout", error.message)
  if (!data) throw ApiError.notFound("Workout not found")

  return rowToWorkout(data)
}

export const createWorkout = async (dto) => {
  const { data: workoutRow, error: insertError } = await supabase
    .from("workouts")
    .insert(dtoToRow(dto))
    .select("*")
    .single()

  if (insertError) throw ApiError.badRequest("Failed to create workout", insertError.message)

  const links = dto.categoryIds.map((categoryId) => ({
    workout_id: workoutRow.id,
    category_id: categoryId,
  }))

  const { error: linkError } = await supabase.from("workout_category_map").insert(links)

  if (linkError) {
    throw ApiError.badRequest("Failed to link workout to categories", linkError.message)
  }

  const { data, error } = await supabase
    .from("workouts")
    .select(SELECT_WITH_CATEGORIES)
    .eq("id", workoutRow.id)
    .single()

  if (error) throw ApiError.badRequest("Failed to load created workout", error.message)

  return rowToWorkout(data)
}
