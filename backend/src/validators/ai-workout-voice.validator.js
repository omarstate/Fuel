import { z } from "zod"

// Validators + pure normalizers for VOICE SET LOGGING (POST
// /ai/workouts/voice-log and .../voice-log/commit). Kept separate from
// ai-voice.validator.js (meals) so the two voice features stay independent —
// the shapes look similar but they diverge on purpose.

// Optional UI language. Egyptian Arabic is the primary language for this
// feature, but the default stays "en" to match every other endpoint's contract.
const langSchema = z.enum(["en", "ar"]).optional().default("en")

// The unit the user's app is set to. Bare spoken numbers are read in this unit;
// the model may still override it per set group when the user says "رطل"/"lb".
const unitSchema = z.enum(["kg", "lb"]).optional().default("kg")

// Hard caps on what one utterance can produce.
export const MAX_VOICE_EXERCISES = 8
export const MAX_SETS_PER_EXERCISE = 12
export const MAX_TOTAL_SETS = 40
// How many of the session's current exercises we show the model.
export const MAX_SESSION_EXERCISES_IN_PROMPT = 20

export const LB_TO_KG = 0.45359237

// workout_session_sets.weight is numeric(6,2) — anything at or above 10000
// would abort the client's insert. Clamping well below that (no human lifts
// 500kg on a logged set) turns a model hallucination into a survivable number.
const MAX_WEIGHT_KG = 500
const MAX_REPS = 100

// -------------------------------------------------------------------------
// POST /ai/workouts/voice-log
// -------------------------------------------------------------------------

// The exercises already in the user's live session, sent by the app so the
// model can resolve "كمان سِت" / "another set" / "same weight" against them.
// `id` is the workout_session_exercises row id — the app writes the set rows
// itself, this endpoint only points at them.
const sessionExerciseSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(160),
  workoutId: z.string().uuid().nullish(),
  setCount: z.coerce.number().int().nonnegative().optional().default(0),
  lastWeight: z.coerce.number().finite().nullish(),
  lastReps: z.coerce.number().int().nullish(),
})

export const voiceSetLogRequestSchema = z.object({
  transcript: z.string().trim().min(2).max(1200),
  lang: langSchema,
  unit: unitSchema,
  sessionExercises: z
    .array(sessionExerciseSchema)
    .max(MAX_SESSION_EXERCISES_IN_PROMPT)
    .optional()
    .default([]),
})

// One set group as returned by the parse Gemini call: a weight/reps pair plus
// how many times it was performed ("تلات مجموعات" → count 3). Loose on the way
// in — the service normalizes and clamps every number itself.
export const voiceSetGroupSchema = z.object({
  weight: z.coerce.number().finite().nullish(),
  unit: z.enum(["kg", "lb"]).nullish(),
  reps: z.coerce.number().finite().nullish(),
  count: z.coerce.number().finite().nullish(),
  note: z.string().trim().min(1).max(120).nullish(),
})

// One exercise as returned by the parse call. Individual exercises are
// safeParsed and dropped when junk, so a single hallucinated entry never fails
// the whole utterance. `sets` stays permissive for the same reason.
export const voiceParsedExerciseSchema = z.object({
  spoken: z.string().trim().min(1).max(200).nullish(),
  name: z.string().trim().min(1).max(160),
  nameAr: z.string().trim().min(1).max(160).nullish(),
  workoutId: z.string().trim().min(1).max(64).nullish(),
  sessionExerciseId: z.string().trim().min(1).max(64).nullish(),
  bodyweight: z.coerce.boolean().nullish(),
  confidence: z.enum(["high", "medium", "low"]).nullish(),
  sets: z.array(voiceSetGroupSchema).optional().default([]),
})

// Outer envelope. `exercises` stays `unknown[]` here so the service can drop
// individual bad entries instead of rejecting the whole reply.
export const voiceSetParseSchema = z.object({
  exercises: z.array(z.unknown()).optional().default([]),
})

// -------------------------------------------------------------------------
// POST /ai/workouts/voice-log/commit
// -------------------------------------------------------------------------

const aliasSchema = z.string().trim().min(1).max(80)

// `workouts` has public-read RLS with NO insert/update policies, so these
// catalog-side writes can only happen here, through the service-role client.
export const commitVoiceSetLogRequestSchema = z.object({
  aliasUpdates: z
    .array(
      z.object({
        workoutId: z.string().uuid(),
        aliases: z.array(aliasSchema).min(1).max(5),
      })
    )
    .max(MAX_VOICE_EXERCISES)
    .optional()
    .default([]),
  newWorkouts: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(120),
        primaryMuscle: z.string().trim().max(60).nullish(),
        equipment: z.string().trim().max(60).nullish(),
        aliases: z.array(aliasSchema).max(5).optional().default([]),
      })
    )
    .max(MAX_VOICE_EXERCISES)
    .optional()
    .default([]),
})

// -------------------------------------------------------------------------
// Pure normalizers
// -------------------------------------------------------------------------

/**
 * Coerce a spoken weight to kilograms, or null when there isn't one.
 * Converts from pounds when that's what was said, rounds to 2dp (the column is
 * numeric(6,2)) and clamps to a humanly possible load — overflow protection
 * here is correctness, not politeness: an un-clamped hallucination makes the
 * app's own insert fail with a numeric overflow the user can't act on.
 *
 * @param {unknown} value
 * @param {"kg"|"lb"} unit  the unit the number was spoken in
 * @returns {number | null} kilograms
 */
export const normalizeWeight = (value, unit = "kg") => {
  const n = Number(value)
  if (!Number.isFinite(n) || n <= 0) return null

  const kg = unit === "lb" ? n * LB_TO_KG : n
  const rounded = Math.round(kg * 100) / 100
  if (!Number.isFinite(rounded) || rounded <= 0) return null

  return Math.min(rounded, MAX_WEIGHT_KG)
}

/**
 * Coerce a spoken rep count to an integer in [1, 100], or null.
 * @param {unknown} value
 * @returns {number | null}
 */
export const normalizeReps = (value) => {
  const n = Math.round(Number(value))
  if (!Number.isFinite(n) || n < 1) return null
  return Math.min(n, MAX_REPS)
}

/**
 * How many times one set group was performed. Anything missing or nonsensical
 * means "once" — a group always represents at least one real set.
 * @param {unknown} value
 * @returns {number}
 */
export const normalizeSetCount = (value) => {
  const n = Math.round(Number(value))
  if (!Number.isFinite(n) || n < 1) return 1
  return Math.min(n, MAX_SETS_PER_EXERCISE)
}

/**
 * Flatten set groups into the individual sets the app will insert: "تلات
 * مجموعات مية كيلو خمس عدات" (one group, count 3) becomes three numbered sets.
 * Truncates at `maxSets` so one utterance can't produce a hundred rows.
 *
 * @param {unknown} groups
 * @param {{ maxSets?: number, unit?: "kg"|"lb" }} options
 *   `unit` is the request-level default; a group's own `unit` wins when set.
 * @returns {{ setNumber: number, weight: number|null, reps: number|null, note: string|null }[]}
 */
export const expandSetGroups = (groups, { maxSets = MAX_SETS_PER_EXERCISE, unit = "kg" } = {}) => {
  const sets = []
  if (maxSets <= 0) return sets

  for (const group of Array.isArray(groups) ? groups : []) {
    if (!group || typeof group !== "object") continue

    const weight = normalizeWeight(group.weight, group.unit === "lb" || group.unit === "kg" ? group.unit : unit)
    const reps = normalizeReps(group.reps)
    const note = typeof group.note === "string" && group.note.trim() ? group.note.trim().slice(0, 120) : null
    const count = normalizeSetCount(group.count)

    for (let i = 0; i < count; i += 1) {
      if (sets.length >= maxSets) return sets
      sets.push({ setNumber: sets.length + 1, weight, reps, note })
    }
  }

  return sets
}
