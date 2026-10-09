import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { isAdmin } from "../utils/is-admin.js"
import { ApiError } from "../utils/api-error.js"
import {
  listExercisesQuerySchema,
  exerciseSlugSchema,
} from "../validators/exercise-catalog.validator.js"
import * as exerciseCatalogService from "../services/exercise-catalog.service.js"

// Refreshing the mirror rewrites ~870 rows from a third-party URL — an
// operator action, not a user one. ADMIN_EMAILS is the same allowlist that
// gates editing someone else's catalog meal (utils/is-admin.js).
export const importExerciseCatalog = async (req, res) => {
  assertSupabaseConfigured()
  if (!isAdmin(req.user)) {
    throw ApiError.forbidden("Only an admin can import the exercise catalog.")
  }
  const data = await exerciseCatalogService.importExerciseCatalog()
  res.json({ data })
}

// Paginated `{ data, count }` exactly like GET /meals and GET /workouts, so the
// clients' existing list/paging helpers work unchanged.
export const listExercises = async (req, res) => {
  assertSupabaseConfigured()
  const filters = listExercisesQuerySchema.parse(req.query)
  const { data, count } = await exerciseCatalogService.listExercises(filters)
  res.json({ data, count })
}

export const addExercise = async (req, res) => {
  assertSupabaseConfigured()
  const slug = exerciseSlugSchema.parse(req.params.slug)
  const { workout, created } = await exerciseCatalogService.addExerciseToWorkouts(
    req.user.id,
    slug
  )
  // 200 either way: "it's already in your library" is a success, not a conflict,
  // and `created` is what the picker renders ("Added" vs "In library").
  res.json({ data: { workout, created } })
}
