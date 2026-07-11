import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { createWorkoutSchema } from "../validators/workouts.validator.js"
import * as workoutsService from "../services/workouts.service.js"

const toPositiveInt = (value) => {
  const parsed = Number.parseInt(value, 10)
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined
}

export const listWorkouts = async (req, res) => {
  assertSupabaseConfigured()
  const { category, search, limit, offset } = req.query

  const { data, count } = await workoutsService.listWorkouts({
    category: typeof category === "string" && category.length > 0 ? category : undefined,
    search: typeof search === "string" && search.length > 0 ? search : undefined,
    limit: toPositiveInt(limit),
    offset: toPositiveInt(offset),
  })

  res.json({ data, count })
}

export const listWorkoutsGrouped = async (_req, res) => {
  assertSupabaseConfigured()
  const data = await workoutsService.listWorkoutsGrouped()
  res.json({ data })
}

export const getWorkoutById = async (req, res) => {
  assertSupabaseConfigured()
  const data = await workoutsService.getWorkoutById(req.params.id)
  res.json({ data })
}

export const createWorkout = async (req, res) => {
  assertSupabaseConfigured()
  const dto = createWorkoutSchema.parse(req.body)
  const data = await workoutsService.createWorkout(dto)
  res.status(201).json({ data })
}
