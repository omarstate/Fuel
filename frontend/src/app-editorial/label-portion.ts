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
  /** grams (or ml) in one printed serving, retained from the label. */
  servingGrams: number | null
  base: Record<MacroKey, number>
  /** grams eaten — a string so the input stays controlled. */
  grams: string
  /** number of servings — derived from grams for display when both apply. */
  servings: string
  calories: string
  protein: string
  carbs: string
  fat: string
  confidence: LabelLike["confidence"]
  note: string
  ok: boolean
}

const round2 = (n: number) => Math.round(n * 100) / 100

/** Grams that one portion "unit" represents: 100 for per-100g labels, one
 * serving's grams for per-serving labels (null when that isn't printed). Drives
 * whether we can offer a grams-eaten control at all. */
export function gramsPerUnit(r: Pick<Review, "basis" | "servingGrams">): number | null {
  return r.basis === "per_100g" ? 100 : r.servingGrams
}

export function canUseGrams(r: Pick<Review, "basis" | "servingGrams">): boolean {
  return gramsPerUnit(r) !== null
}

export function portionFactor(
  r: Pick<Review, "basis" | "grams" | "servings" | "servingGrams">
): number {
  const per = gramsPerUnit(r)
  return per !== null ? (Number(r.grams) || 0) / per : Number(r.servings) || 0
}

export function scaled(base: Record<MacroKey, number>, factor: number): Record<MacroKey, string> {
  return {
    calories: String(Math.round(base.calories * factor)),
    protein: String(Math.round(base.protein * factor)),
    carbs: String(Math.round(base.carbs * factor)),
    fat: String(Math.round(base.fat * factor)),
  }
}

/** Apply a portion edit: keep grams and servings in sync whenever the label
 * printed a serving size (grams is authoritative; servings is derived), then
 * rescale the macro totals from `base`. Replaces the per-dialog `setPortion`. */
export function applyPortion(
  prev: Review,
  patch: { grams?: string; servings?: string }
): Review {
  const sg = prev.servingGrams
  const next = { ...prev, ...patch }
  if (sg !== null && sg > 0) {
    if (patch.grams !== undefined) {
      const g = Number(patch.grams)
      next.servings =
        patch.grams.trim() === "" || !Number.isFinite(g) ? "" : String(round2(g / sg))
    } else if (patch.servings !== undefined) {
      const n = Number(patch.servings)
      next.grams =
        patch.servings.trim() === "" || !Number.isFinite(n) ? "" : String(Math.round(n * sg))
    }
  }
  return { ...next, ...scaled(next.base, portionFactor(next)) }
}

export function toReview(e: LabelLike): Review {
  const base: Record<MacroKey, number> = {
    calories: e.calories,
    protein: e.protein,
    carbs: e.carbs,
    fat: e.fat,
  }
  // Default portion:
  // - per_100g → grams = the printed serving size, else 100 (unchanged).
  // - per_serving with a known serving size → one whole serving in grams.
  // - per_serving without → one serving, no grams control.
  let grams: string
  if (e.basis === "per_100g") {
    grams = String(e.servingGrams ?? 100)
  } else {
    grams = e.servingGrams !== null ? String(e.servingGrams) : ""
  }
  const servings = "1"
  const factor = portionFactor({ basis: e.basis, grams, servings, servingGrams: e.servingGrams })
  return {
    name: e.name ?? "",
    basis: e.basis,
    servingSize: e.servingSize,
    servingGrams: e.servingGrams,
    base,
    grams,
    servings,
    ...scaled(base, factor),
    confidence: e.confidence,
    note: e.note,
    ok: e.ok,
  }
}

/** The `serving_size` text stored on the logged row: the grams eaten when we
 * have a grams basis, otherwise a servings description; falls back to the
 * printed serving size when the portion field is empty. */
export function eatenText(r: Review): string {
  if (canUseGrams(r)) {
    const g = r.grams.trim()
    return g !== "" ? `${g} g` : r.servingSize
  }
  const s = r.servings.trim()
  if (s === "") return r.servingSize
  return r.servingSize ? `${s} × ${r.servingSize}` : `${s} serving${s === "1" ? "" : "s"}`
}

/** Per-100g-normalized values (with a serving-size string) for the shared
 * catalog save. Recovers the label's per-basis numbers from the current edited
 * fields, then normalizes to per 100 g when a grams basis exists; otherwise
 * saves the per-serving values as-is. Returns null (skip the save) when the
 * recovered calories are non-positive. */
export function toCatalogBase(
  r: Review
): { servingSize: string; calories: number; protein: number; carbs: number; fat: number } | null {
  const factor = portionFactor(r)
  const per = gramsPerUnit(r)
  const recover = (key: MacroKey) =>
    factor > 0 ? (Number(r[key]) || 0) / factor : r.base[key]
  const perBasis: Record<MacroKey, number> = {
    calories: recover("calories"),
    protein: recover("protein"),
    carbs: recover("carbs"),
    fat: recover("fat"),
  }
  if (per !== null) {
    const norm = {
      calories: Math.round((perBasis.calories * 100) / per),
      protein: Math.round((perBasis.protein * 100) / per),
      carbs: Math.round((perBasis.carbs * 100) / per),
      fat: Math.round((perBasis.fat * 100) / per),
    }
    if (norm.calories <= 0) return null
    return { servingSize: "100 g", ...norm }
  }
  const rounded = {
    calories: Math.round(perBasis.calories),
    protein: Math.round(perBasis.protein),
    carbs: Math.round(perBasis.carbs),
    fat: Math.round(perBasis.fat),
  }
  if (rounded.calories <= 0) return null
  return { servingSize: r.servingSize.trim() || "1 serving", ...rounded }
}

/** Pull the grams (or ml) out of a catalog `serving_size` string so the library
 * portion popover can offer a grams input. Prefers a parenthesized quantity
 * ("1 cup (240 ml)" → 240), else the first number+unit. kg/l scale ×1000.
 * Returns null when nothing usable is found. */
export function parseServingGrams(text: string | null | undefined): number | null {
  if (!text) return null
  // The unit must not be the start of a longer word ("1 large" is not 1 litre).
  const re = /(\d+(?:[.,]\d+)?)\s*(kg|كجم|جرام|جم|grams?|gm|ml|مل|g|l)(?![a-z؀-ۿ])/i
  const paren = text.match(/\(([^)]*)\)/)
  for (const chunk of paren ? [paren[1], text] : [text]) {
    const m = chunk.match(re)
    if (!m) continue
    const num = parseFloat(m[1].replace(",", "."))
    if (!Number.isFinite(num)) continue
    const unit = m[2].toLowerCase()
    const grams = num * (unit === "kg" || unit === "كجم" || unit === "l" ? 1000 : 1)
    if (grams > 0) return grams
  }
  return null
}
