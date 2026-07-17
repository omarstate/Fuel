import { z } from "zod"

// POST /ai/meals/lookup body.
export const lookupRequestSchema = z.object({
  query: z.string().trim().min(2).max(200),
})

const nonNegative = z.number().nonnegative()
const rangeTuple = z.tuple([nonNegative, nonNegative])

// One meal item as returned by Gemini. Loose on the way in — the service
// clamps/rounds after parsing.
export const aiMealItemSchema = z.object({
  name: z.string().trim().min(1).max(120),
  brand: z.string().trim().optional().nullable(),
  servingSize: z.string().trim().optional().nullable(),
  calories: nonNegative,
  protein: nonNegative,
  carbs: nonNegative,
  fat: nonNegative,
  ranges: z
    .object({
      calories: rangeTuple,
      protein: rangeTuple,
      carbs: rangeTuple,
      fat: rangeTuple,
    })
    .optional()
    .nullable(),
  confidence: z.enum(["official", "estimate"]),
  sourceUrl: z.string().url().optional().nullable(),
  sourceTitle: z.string().trim().optional().nullable(),
})

export const aiMealArraySchema = z.array(aiMealItemSchema).min(1).max(5)

const roundInt = (value) => Math.max(0, Math.round(value))

const MACRO_KEYS = ["calories", "protein", "carbs", "fat"]

// Round point values to ints; validate/normalize ranges (min<=max, ints),
// dropping the whole ranges object if any tuple is inconsistent.
export const normalizeAiMeal = (item) => {
  const normalized = {
    ...item,
    calories: roundInt(item.calories),
    protein: roundInt(item.protein),
    carbs: roundInt(item.carbs),
    fat: roundInt(item.fat),
    ranges: null,
  }

  if (item.ranges) {
    let valid = true
    const ranges = {}
    for (const key of MACRO_KEYS) {
      const tuple = item.ranges[key]
      const min = roundInt(tuple[0])
      const max = roundInt(tuple[1])
      if (min > max) {
        valid = false
        break
      }
      ranges[key] = [min, max]
    }
    if (valid) normalized.ranges = ranges
  }

  return normalized
}

// Coach-insights narrative returned by Gemini (before we attach server-computed
// facts). Kept forgiving on length; the prompt asks for the shape.
export const insightsSchema = z.object({
  headline: z.string().trim().min(1).max(200),
  insights: z
    .array(
      z.object({
        title: z.string().trim().min(1).max(120),
        body: z.string().trim().min(1).max(400),
      })
    )
    .min(1)
    .max(6),
  tips: z.array(z.string().trim().min(1).max(200)).min(1).max(5),
})
