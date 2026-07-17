import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { assertGeminiConfigured } from "../utils/assert-gemini-configured.js"
import { lookupRequestSchema } from "../validators/ai.validator.js"
import * as aiService from "../services/ai.service.js"

export const lookupMeals = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const { query } = lookupRequestSchema.parse(req.body)
  const data = await aiService.lookupMeals(req.user.id, query)
  res.json({ data })
}

export const getInsights = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const refresh = req.query.refresh === "1"
  const data = await aiService.getInsights(req.user.id, { refresh })
  res.json({ data })
}
