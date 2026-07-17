import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import {
  createMealSchema,
  updateMealSchema,
  estimateMealsSchema,
  aiCatalogMealsSchema,
} from "../validators/meals.validator.js"
import * as mealsService from "../services/meals.service.js"
import { estimateMeals as estimateMealsAi } from "../services/ai-nutrition.service.js"

const toPositiveInt = (value) => {
  const parsed = Number.parseInt(value, 10)
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined
}

export const listMeals = async (req, res) => {
  assertSupabaseConfigured()
  const { category, search, limit, offset } = req.query

  const { data, count } = await mealsService.listMeals({
    category: typeof category === "string" && category.length > 0 ? category : undefined,
    search: typeof search === "string" && search.length > 0 ? search : undefined,
    limit: toPositiveInt(limit),
    offset: toPositiveInt(offset),
  })

  res.json({ data, count })
}

export const listMealsGrouped = async (_req, res) => {
  assertSupabaseConfigured()
  const data = await mealsService.listMealsGrouped()
  res.json({ data })
}

export const listMyMeals = async (req, res) => {
  assertSupabaseConfigured()
  const data = await mealsService.listMyMeals(req.user.id)
  res.json({ data })
}

export const getMealById = async (req, res) => {
  assertSupabaseConfigured()
  const data = await mealsService.getMealById(req.params.id)
  res.json({ data })
}

export const createMeal = async (req, res) => {
  assertSupabaseConfigured()
  const dto = createMealSchema.parse(req.body)
  const data = await mealsService.createMeal(dto, req.user.id)
  res.status(201).json({ data })
}

export const updateMeal = async (req, res) => {
  assertSupabaseConfigured()
  const dto = updateMealSchema.parse(req.body)
  const data = await mealsService.updateMeal(req.params.id, dto, req.user)
  res.json({ data })
}

export const deleteMeal = async (req, res) => {
  assertSupabaseConfigured()
  const data = await mealsService.deleteMeal(req.params.id, req.user)
  res.json({ data })
}

// AI nutrition estimation — no Supabase dependency, just Gemini. Returns one
// estimate per item so the client can show a review step before logging.
export const estimateMeals = async (req, res) => {
  const { place, items } = estimateMealsSchema.parse(req.body)
  const data = await estimateMealsAi({ place, items })
  res.json({ data })
}

// Commit reviewed AI meals to the shared catalog under the "AI" category.
export const createAiCatalogMeals = async (req, res) => {
  assertSupabaseConfigured()
  const { meals } = aiCatalogMealsSchema.parse(req.body)
  const data = await mealsService.createAiCatalogMeals(meals, req.user.id)
  res.status(201).json({ data })
}
