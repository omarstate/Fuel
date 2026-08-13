import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { assertGeminiConfigured } from "../utils/assert-gemini-configured.js"
import {
  voiceSetLogRequestSchema,
  commitVoiceSetLogRequestSchema,
} from "../validators/ai-workout-voice.validator.js"
import * as aiWorkoutVoiceService from "../services/ai-workout-voice.service.js"

// Parse a spoken mid-workout transcript into exercises + sets. Writes nothing —
// the app shows a review sheet, then commits the catalog side and inserts its
// own session rows under RLS.
export const parseVoiceSetLog = async (req, res) => {
  assertSupabaseConfigured()
  assertGeminiConfigured()
  const { transcript, lang, unit, sessionExercises } = voiceSetLogRequestSchema.parse(req.body)
  const data = await aiWorkoutVoiceService.parseVoiceSetLog({
    transcript,
    lang,
    unit,
    sessionExercises,
  })
  res.json({ data })
}

// Persist the catalog side of a confirmed voice set log: save newly named
// exercises and teach matched ones the phrase the user actually spoke. This has
// to live on the backend — `workouts` is public-read with no insert/update
// policies, so only the service-role client can write it. NOTE: no
// assertGeminiConfigured — this path never calls Gemini.
export const commitVoiceSetLog = async (req, res) => {
  assertSupabaseConfigured()
  const { aliasUpdates, newWorkouts } = commitVoiceSetLogRequestSchema.parse(req.body)
  const data = await aiWorkoutVoiceService.commitVoiceSetLog(req.user.id, { aliasUpdates, newWorkouts })
  res.json({ data })
}
