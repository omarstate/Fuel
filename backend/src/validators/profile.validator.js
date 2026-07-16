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
