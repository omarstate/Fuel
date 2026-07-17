// Pure portion-scaling for photographed labels. A label states macros on some
// basis (per 100g or per serving); the user tells us how much they ate and we
// scale. Kept separate from the dialog so this — the error-prone bit — is
// independently testable and has no React dependency.

export const MACROS = ["calories", "protein", "carbs", "fat"] as const
export type MacroKey = (typeof MACROS)[number]

/** The subset of fields `toReview` needs. Both the photo extraction
 * (`ExtractedLabel`) and the barcode lookup (`BarcodeProduct`) satisfy it, so
 * the review/scale UI is shared between the two features. */
export type LabelLike = {
  name: string | null
  basis: "per_100g" | "per_serving"
  servingSize: string
  servingGrams: number | null
  calories: number
  protein: number
  carbs: number
  fat: number
  confidence: "high" | "medium" | "low" | null
  note: string
  ok: boolean
}

// Editable review state. `base` holds the values as read off the label (on its
// own basis) so the totals can be rescaled when the portion changes; the string
// fields are the final numbers that actually get logged.
export type Review = {
  name: string
  basis: LabelLike["basis"]
  servingSize: string
  base: Record<MacroKey, number>
  /** grams eaten (per_100g) — a string so the input stays controlled. */
  grams: string
  /** number of servings (per_serving). */
  servings: string
  calories: string
  protein: string
  carbs: string
  fat: string
  confidence: LabelLike["confidence"]
  note: string
  ok: boolean
}

export function portionFactor(r: Pick<Review, "basis" | "grams" | "servings">): number {
  return r.basis === "per_100g" ? (Number(r.grams) || 0) / 100 : Number(r.servings) || 0
}

export function scaled(base: Record<MacroKey, number>, factor: number): Record<MacroKey, string> {
  return {
    calories: String(Math.round(base.calories * factor)),
    protein: String(Math.round(base.protein * factor)),
    carbs: String(Math.round(base.carbs * factor)),
    fat: String(Math.round(base.fat * factor)),
  }
}

export function toReview(e: LabelLike): Review {
  const base: Record<MacroKey, number> = {
    calories: e.calories,
    protein: e.protein,
    carbs: e.carbs,
    fat: e.fat,
  }
  // Default portion: one printed serving if the label gave a serving size,
  // otherwise the basis as stated (100g, or one serving).
  const grams = e.basis === "per_100g" ? String(e.servingGrams ?? 100) : "100"
  const servings = "1"
  const factor = e.basis === "per_100g" ? (Number(grams) || 0) / 100 : 1
  return {
    name: e.name ?? "",
    basis: e.basis,
    servingSize: e.servingSize,
    base,
    grams,
    servings,
    ...scaled(base, factor),
    confidence: e.confidence,
    note: e.note,
    ok: e.ok,
  }
}
