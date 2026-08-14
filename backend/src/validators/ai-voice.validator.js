import { z } from "zod"

// Validators + pure normalizers for voice meal logging (POST /ai/meals/voice-log
// and .../voice-log/commit). Kept separate from ai.validator.js so the two AI
// features stay independent; the ranges normalizer is a deliberate copy of
// `normalizeAiMeal`'s logic rather than an import.
//
// Parsing, catalog matching and macro estimation all come back from ONE Gemini
// call, so there is a single item schema (`voiceParsedItemSchema`) rather than a
// separate per-item estimate schema.

// Optional UI language. Egyptian Arabic is the primary language for this
// feature, but the default stays "en" to match every other endpoint's contract.
const langSchema = z.enum(["en", "ar"]).optional().default("en")

export const MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"]

// Hard cap on how many items one utterance can produce.
export const MAX_VOICE_ITEMS = 15

// -------------------------------------------------------------------------
// POST /ai/meals/voice-log
// -------------------------------------------------------------------------

// `transcript` + `lang` stay the required contract: old app builds and the
// typed-fallback path send only those. Newer builds race TWO on-device speech
// recognizers (Egyptian Arabic + English) over the SAME audio and additionally
// send both readings in `transcripts`, letting the model decide which one is
// real speech instead of trusting whichever recognizer finished first.
// `transcripts` is best-effort by design — the `catch` drops a malformed array
// (e.g. a one-character gibberish reading from the losing recognizer) so the
// request degrades to the single-transcript path instead of failing outright.
export const voiceLogRequestSchema = z.object({
  transcript: z.string().trim().min(2).max(1200),
  lang: langSchema,
  transcripts: z
    .array(
      z.object({
        lang: z.enum(["en", "ar"]),
        text: z.string().trim().min(2).max(1200),
      })
    )
    .max(2)
    .optional()
    .catch(undefined),
})

const nonNegative = z.number().nonnegative()
const rangeTuple = z.tuple([nonNegative, nonNegative])

export const macroRangesSchema = z.object({
  calories: rangeTuple,
  protein: rangeTuple,
  carbs: rangeTuple,
  fat: rangeTuple,
})

// One item as returned by the single parse + match + estimate Gemini call.
// Loose on the way in — the service clamps the factor and re-checks catalog ids
// against the rows it actually fetched. Individual items are safeParsed and
// dropped when junk, so a single hallucinated entry never fails the whole
// utterance. The macro fields are only populated for items the model could not
// match to the catalog (`catalogId: null`); matched items carry nulls and take
// their macros from the catalog row instead.
export const voiceParsedItemSchema = z.object({
  spoken: z.string().trim().min(1).max(200).nullish(),
  name: z.string().trim().min(1).max(160),
  nameAr: z.string().trim().min(1).max(160).nullish(),
  quantity: z.coerce.number().finite().nullish(),
  unit: z.string().trim().min(1).max(40).nullish(),
  catalogId: z.string().trim().min(1).max(64).nullish(),
  factor: z.coerce.number().finite().nullish(),
  confidence: z.enum(["high", "medium", "low"]).nullish(),
  servingSize: z.string().trim().max(120).nullish(),
  calories: z.coerce.number().finite().nullish(),
  protein: z.coerce.number().finite().nullish(),
  carbs: z.coerce.number().finite().nullish(),
  fat: z.coerce.number().finite().nullish(),
  ranges: macroRangesSchema.nullish(),
  note: z.string().trim().max(400).nullish(),
})

// Outer envelope. `items` stays `unknown[]` here so the service can drop
// individual bad entries instead of rejecting the whole reply.
export const voiceParseSchema = z.object({
  mealType: z.enum(MEAL_TYPES).nullish(),
  items: z.array(z.unknown()).optional().default([]),
})

// -------------------------------------------------------------------------
// POST /ai/meals/voice-log/commit
// -------------------------------------------------------------------------

const macroInt = z.coerce
  .number()
  .finite()
  .nonnegative()
  .transform((value) => Math.round(value))

const aliasSchema = z.string().trim().min(1).max(80)

export const commitVoiceLogRequestSchema = z.object({
  newMeals: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(120),
        servingSize: z.string().trim().min(1).max(80),
        calories: macroInt,
        protein: macroInt,
        carbs: macroInt,
        fat: macroInt,
        sourceUrl: z.string().url().nullable().catch(null),
        ranges: macroRangesSchema.nullable().optional().catch(null),
        aliases: z.array(aliasSchema).max(5).optional().default([]),
      })
    )
    .max(MAX_VOICE_ITEMS)
    .optional()
    .default([]),
  aliasUpdates: z
    .array(
      z.object({
        catalogMealId: z.string().uuid(),
        aliases: z.array(aliasSchema).min(1).max(5),
      })
    )
    .max(MAX_VOICE_ITEMS)
    .optional()
    .default([]),
})

// -------------------------------------------------------------------------
// Pure normalizers
// -------------------------------------------------------------------------

const MACRO_KEYS = ["calories", "protein", "carbs", "fat"]

export const roundInt = (value) => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n > 0 ? n : 0
}

// Serving multipliers outside this band are always a model mistake.
const FACTOR_MIN = 0.1
const FACTOR_MAX = 20

/** Clamp a spoken-amount ÷ serving-size multiplier; null/garbage becomes 1. */
export const clampFactor = (value) => {
  const n = Number(value)
  if (!Number.isFinite(n) || n <= 0) return 1
  return Math.min(Math.max(n, FACTOR_MIN), FACTOR_MAX)
}

/**
 * Round each [min,max] tuple to ints and drop the WHOLE ranges object when any
 * tuple is inconsistent (min > max) — same rule as `normalizeAiMeal`, so the
 * ranges the app renders always make sense.
 */
export const normalizeRanges = (ranges) => {
  if (!ranges) return null
  const normalized = {}
  for (const key of MACRO_KEYS) {
    const tuple = ranges[key]
    if (!Array.isArray(tuple) || tuple.length < 2) return null
    const min = roundInt(tuple[0])
    const max = roundInt(tuple[1])
    if (min > max) return null
    normalized[key] = [min, max]
  }
  return normalized
}
