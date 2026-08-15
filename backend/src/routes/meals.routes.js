import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import {
  listMeals,
  listMealsGrouped,
  listMyMeals,
  getMealById,
  createMeal,
  updateMeal,
  deleteMeal,
  estimateMeals,
  extractMealPhoto,
  lookupBarcode,
  reportBarcode,
  createAiCatalogMeals,
} from "../controllers/meals.controller.js"

export const mealsRouter = Router()

// /meals/grouped and /meals/mine must be declared before /meals/:id so
// "grouped"/"mine" aren't swallowed as an id param.
mealsRouter.get("/meals/grouped", asyncHandler(listMealsGrouped))
mealsRouter.get("/meals/mine", requireAuth, asyncHandler(listMyMeals))
mealsRouter.get("/meals", asyncHandler(listMeals))
mealsRouter.get("/meals/:id", asyncHandler(getMealById))
mealsRouter.get("/meals/barcode/:code", requireAuth, asyncHandler(lookupBarcode))
mealsRouter.post("/meals/barcode/:code", requireAuth, asyncHandler(reportBarcode))
mealsRouter.post("/meals/estimate", requireAuth, asyncHandler(estimateMeals))
mealsRouter.post("/meals/photo-extract", requireAuth, asyncHandler(extractMealPhoto))
mealsRouter.post("/meals/ai-catalog", requireAuth, asyncHandler(createAiCatalogMeals))
mealsRouter.post("/meals", requireAuth, asyncHandler(createMeal))
mealsRouter.patch("/meals/:id", requireAuth, asyncHandler(updateMeal))
mealsRouter.delete("/meals/:id", requireAuth, asyncHandler(deleteMeal))
