import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { assertGeminiConfigured } from "../utils/assert-gemini-configured.js"
import {
  voiceLogRequestSchema,
  commitVoiceLogRequestSchema,
} from "../validators/ai-voice.validator.js"
import * as aiVoiceService from "../services/ai-voice.service.js"

// Parse a spoken transcript into loggable items. Writes nothing — the app shows
// a review sheet, then commits the catalog side and inserts its own log rows.
export const parseVoiceLog = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const { transcript, lang } = voiceLogRequestSchema.parse(req.body)
  const data = await aiVoiceService.parseVoiceLog({ transcript, lang })
  res.json({ data })
}

// Persist the catalog side of a confirmed voice log: save newly estimated meals
// and teach matched meals the phrase the user actually spoke. NOTE: no
// assertGeminiConfigured — this path never calls Gemini.
export const commitVoiceLog = async (req, res) => {
  assertSupabaseConfigured()
  const { newMeals, aliasUpdates } = commitVoiceLogRequestSchema.parse(req.body)
  const data = await aiVoiceService.commitVoiceLog(req.user.id, { newMeals, aliasUpdates })
  res.json({ data })
}
