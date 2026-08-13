import { z } from "zod"

export const upsertProfileSchema = z.object({
  sex: z.enum(["male", "female"]),
  age: z.number().int().min(13).max(120),
  heightCm: z.number().min(90).max(260),
  weightKg: z.number().min(30).max(400),
  goalWeightKg: z.number().min(30).max(400),
  activityLevel: z.enum(["sedentary", "light", "moderate", "very", "extra"]),
  pace: z.enum(["mild", "standard", "aggressive"]),
})

// Manual daily-target overrides (PUT /profile/targets). Wide safety bounds
// only — the computed recommendation stays available via PUT /profile.
export const updateTargetsSchema = z.object({
  calories: z.number().int().min(800).max(10000),
  protein: z.number().int().min(10).max(500),
  carbs: z.number().int().min(0).max(1000),
  fat: z.number().int().min(0).max(500),
})
