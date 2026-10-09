import { z } from "zod"

// Browse filters for GET /workouts/exercise-catalog. Everything is optional and
// comes off the query string, so each field coerces from a string and an empty
// value means "no filter" rather than a 400 — a cleared search box shouldn't
// error.
const optionalText = (max) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .transform((value) => (value ? value : undefined))

// Enum values are NOT pinned to the dataset's current vocabulary: the table
// stores them as free text so an upstream release can add a category without a
// migration, and pinning them here would reintroduce exactly that coupling.
export const listExercisesQuerySchema = z.object({
  search: optionalText(120),
  category: optionalText(60),
  muscle: optionalText(60),
  equipment: optionalText(60),
  limit: z.coerce.number().int().positive().max(100).optional(),
  offset: z.coerce.number().int().nonnegative().optional(),
})

// The dataset's own id, used as the path param: letters, digits, underscores,
// hyphens, dots and slashes do appear ("3_4_Sit-Up", "Ab_Roller"). Bounded so a
// pathological param can't reach the database.
export const exerciseSlugSchema = z
  .string()
  .trim()
  .min(1, "slug is required")
  .max(160)
  .regex(/^[A-Za-z0-9_.\-]+$/, "That doesn't look like an exercise id.")
