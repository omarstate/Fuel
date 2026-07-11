import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { listWorkoutCategories } from "../controllers/workout-categories.controller.js"

export const workoutCategoriesRouter = Router()

workoutCategoriesRouter.get("/workout-categories", asyncHandler(listWorkoutCategories))
