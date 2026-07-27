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

// AI estimation input: an optional place ("McDonald's") plus one or more meal
// items. The frontend splits the user's comma-separated text into `items`, but
// we also split defensively here so a single "burger, fries" string still
// becomes two meals. Empty entries are dropped; at least one must survive.
export const estimateMealsSchema = z
  .object({
    place: z.string().trim().max(120).optional(),
    // Optional UI language — names/notes come back in this language. Default en.
    lang: z.enum(["en", "ar"]).optional().default("en"),
    items: z
      .array(z.string())
      .or(z.string())
      .transform((value) =>
        (Array.isArray(value) ? value : [value])
          .flatMap((entry) => entry.split(","))
          .map((entry) => entry.trim())
          .filter(Boolean)
      )
      .pipe(
        z
          .array(z.string().min(1).max(200))
          .min(1, "Add at least one item you ate.")
          .max(20, "That's a lot at once — log up to 20 items at a time.")
      ),
  })

// Photo label-extraction input: a base64-encoded image plus its MIME type. The
// client downscales/compresses before upload, but we cap the base64 length as a
// hard ceiling (~12MB of base64 ≈ 9MB binary) so a giant paste can't exhaust
// memory. A `data:image/...;base64,` prefix (from canvas.toDataURL) is stripped
// so the service gets raw base64 to hand to Gemini.
const MAX_IMAGE_BASE64_CHARS = 12_000_000

export const extractMealPhotoSchema = z.object({
  mimeType: z.enum(["image/jpeg", "image/png", "image/webp"], {
    errorMap: () => ({ message: "Unsupported image type. Use JPEG, PNG, or WebP." }),
  }),
  image: z
    .string()
    .min(1, "image is required")
    .transform((value) => value.replace(/^data:[^;,]+;base64,/, "").trim())
    .pipe(
      z
        .string()
        .min(1, "image is required")
        .max(MAX_IMAGE_BASE64_CHARS, "That image is too large. Use a smaller photo.")
    ),
})

// Barcode lookup path param — EAN-8/UPC-A/EAN-13/GTIN-14 are 8–14 digits.
export const barcodeParamSchema = z
  .string()
  .trim()
  .regex(/^\d{8,14}$/, "That doesn't look like a valid barcode.")

// Reviewed AI meals being committed to the shared catalog. Same macro rules as
// a manual catalog meal, but no categoryId (the server forces the "AI"
// category) and the note is carried in `description`.
const aiCatalogMealSchema = z.object({
  name: nameSchema,
  description: descriptionSchema.optional(),
  servingSize: servingSizeSchema.optional(),
  calories: nonNegativeInt,
  protein: nonNegativeInt.default(0),
  carbs: nonNegativeInt.default(0),
  fat: nonNegativeInt.default(0),
})

export const aiCatalogMealsSchema = z.object({
  meals: z
    .array(aiCatalogMealSchema)
    .min(1, "Provide at least one meal.")
    .max(20, "Save up to 20 meals at a time."),
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
