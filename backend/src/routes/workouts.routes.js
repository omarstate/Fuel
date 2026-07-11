import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import {
  listWorkouts,
  listWorkoutsGrouped,
  getWorkoutById,
  createWorkout,
} from "../controllers/workouts.controller.js"

export const workoutsRouter = Router()

// /workouts/grouped must be declared before /workouts/:id so "grouped" isn't
// swallowed as an id param.
workoutsRouter.get("/workouts/grouped", asyncHandler(listWorkoutsGrouped))
workoutsRouter.get("/workouts", asyncHandler(listWorkouts))
workoutsRouter.get("/workouts/:id", asyncHandler(getWorkoutById))
workoutsRouter.post("/workouts", asyncHandler(createWorkout))
