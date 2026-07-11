import { supabase } from "../config/supabase.js"
import { rowToWorkoutCategory } from "../models/workout-category.model.js"
import { ApiError } from "../utils/api-error.js"

export const listWorkoutCategories = async () => {
  const { data, error } = await supabase
    .from("workout_categories")
    .select("*")
    .order("sort_order", { ascending: true })

  if (error) throw ApiError.badRequest("Failed to load workout categories", error.message)

  return data.map(rowToWorkoutCategory)
}
