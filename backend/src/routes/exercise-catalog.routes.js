import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import {
  importExerciseCatalog,
  listExercises,
  addExercise,
} from "../controllers/exercise-catalog.controller.js"

// These live under /workouts/exercise-catalog rather than a top-level path
// because the feature *is* the workout library's source. That nesting makes
// mount ORDER load-bearing: workoutsRouter declares GET /workouts/:id, which
// would otherwise swallow "exercise-catalog" as an id. routes/index.js mounts
// this router first for exactly that reason — see the comment there.
export const exerciseCatalogRouter = Router()

exerciseCatalogRouter.get(
  "/workouts/exercise-catalog",
  requireAuth,
  asyncHandler(listExercises)
)

// Admin-only (enforced in the controller via ADMIN_EMAILS); re-running is safe.
exerciseCatalogRouter.post(
  "/workouts/exercise-catalog/import",
  requireAuth,
  asyncHandler(importExerciseCatalog)
)

exerciseCatalogRouter.post(
  "/workouts/exercise-catalog/:slug/add",
  requireAuth,
  asyncHandler(addExercise)
)
