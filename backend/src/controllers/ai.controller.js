import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { assertGeminiConfigured } from "../utils/assert-gemini-configured.js"
import { lookupRequestSchema, suggestRequestSchema } from "../validators/ai.validator.js"
import * as aiService from "../services/ai.service.js"

export const lookupMeals = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const { query, lang } = lookupRequestSchema.parse(req.body)
  const data = await aiService.lookupMeals(req.user.id, query, lang)
  res.json({ data })
}

export const getInsights = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const refresh = req.query.refresh === "1"
  const lang = req.query.lang === "ar" ? "ar" : "en"
  const data = await aiService.getInsights(req.user.id, { refresh, lang })
  res.json({ data })
}

// NOTE: deliberately NO assertGeminiConfigured — an unconfigured Gemini must
// still return deterministic suggestions (the service skips the Gemini step and
// falls back), so the feature works without AI.
export const suggestMeals = async (req, res) => {
  assertSupabaseConfigured()
  const { remaining, lang } = suggestRequestSchema.parse(req.body)
  const data = await aiService.suggestMeals(req.user.id, remaining, lang)
  res.json({ data })
}
