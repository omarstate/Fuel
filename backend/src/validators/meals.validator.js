import { z } from "zod"

const nonNegativeInt = z.number().int().nonnegative()

const nameSchema = z.string().trim().min(1, "name is required")
const descriptionSchema = z.string().trim()
const categoryIdSchema = z.string().uuid("categoryId must be a valid uuid")
const servingSizeSchema = z.string().trim()

export const createMealSchema = z.object({
  name: nameSchema,
  description: descriptionSchema.optional(),
  categoryId: categoryIdSchema,
  servingSize: servingSizeSchema.optional(),
  calories: nonNegativeInt,
  protein: nonNegativeInt.default(0),
  carbs: nonNegativeInt.default(0),
  fat: nonNegativeInt.default(0),
})

// Partial version of createMealSchema for PATCH — same per-field rules, but
// every field is optional (no defaults are applied, so an omitted field is
// left untouched rather than reset to 0/null) and at least one must be
// present.
export const updateMealSchema = z
  .object({
    name: nameSchema.optional(),
    description: descriptionSchema.optional(),
    categoryId: categoryIdSchema.optional(),
    servingSize: servingSizeSchema.optional(),
    calories: nonNegativeInt.optional(),
    protein: nonNegativeInt.optional(),
    carbs: nonNegativeInt.optional(),
    fat: nonNegativeInt.optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: "At least one field must be provided",
  })
