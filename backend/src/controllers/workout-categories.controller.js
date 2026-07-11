import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import * as workoutCategoriesService from "../services/workout-categories.service.js"

export const listWorkoutCategories = async (_req, res) => {
  assertSupabaseConfigured()
  const data = await workoutCategoriesService.listWorkoutCategories()
  res.json({ data })
}
