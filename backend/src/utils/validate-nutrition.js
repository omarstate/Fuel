// Arithmetic sanity checks for AI-produced nutrition numbers.
//
// Every AI surface (lookup, free-text estimate, voice, label photo) asks a model
// for calories AND macros, which gives us a cheap consistency test the model
// never sees: the two have to agree under the Atwater factors. When they don't,
// we trust the MACROS — they come off labels and recipes and are much harder to
// hallucinate consistently than a single headline calorie figure, which models
// love to round to a memorable number.
//
// Pure functions, no DB access, no imports. Callers decide what a flag means
// (in practice: downgrade the item's self-reported confidence).

// Below this many "macro calories" the check is meaningless and actively wrong:
// water, diet soda and black coffee legitimately report ~0 macros next to a
// small non-zero kcal figure.
const ATWATER_MIN_KCAL = 20

// How far calories may drift from the macro arithmetic before we rewrite them.
// Labels round, and fibre/alcohol/sugar-alcohol accounting moves the number a
// few percent on its own, so a tight band would fire on honest data.
const ATWATER_TOLERANCE = 0.15

// Plausible energy density of anything edible, kcal per gram. Pure fat is 9,
// pure water 0 — outside this band the serving weight and the macros are
// describing different things.
const MIN_KCAL_PER_GRAM = 0.1
const MAX_KCAL_PER_GRAM = 9.5

/** Finite, non-negative, or 0. Never throws, whatever the model sent. */
const toAmount = (value) => {
  const n = Number(value)
  return Number.isFinite(n) && n > 0 ? n : 0
}

/**
 * Cross-check one item's calories against its macros, and its macros against
 * its serving weight.
 *
 * @param {{
 *   calories: unknown, protein: unknown, carbs: unknown, fat: unknown,
 *   servingGrams?: unknown,
 * }} input  all on the SAME basis (one serving, or per 100 g — just be consistent)
 * @returns {{ calories: number, adjusted: boolean, flags: string[] }}
 *   `calories` is always a finite non-negative integer: the reconciled figure
 *   when `adjusted`, otherwise the input rounded. Flags are advisory:
 *   - "calories-reconciled"  calories were rewritten from the macros
 *   - "implausible-density"  kcal per gram of serving is outside [0.1, 9.5]
 *   - "macros-exceed-weight" protein + carbs + fat weigh more than the serving
 */
export const reconcileNutrition = ({ calories, protein, carbs, fat, servingGrams = null }) => {
  const kcal = toAmount(calories)
  const p = toAmount(protein)
  const c = toAmount(carbs)
  const f = toAmount(fat)

  const flags = []
  let adjusted = false
  let resolved = Math.round(kcal)

  const atwater = 4 * p + 4 * c + 9 * f
  if (atwater >= ATWATER_MIN_KCAL && Math.abs(kcal - atwater) / atwater > ATWATER_TOLERANCE) {
    resolved = Math.round(atwater)
    adjusted = true
    flags.push("calories-reconciled")
  }

  // Weight-based checks only — a serving with no stated grams tells us nothing.
  // Genuinely calorie-free items (water, diet soda: ~0 macros, tiny kcal) sit
  // below MIN_KCAL_PER_GRAM by nature, so the density floor skips them.
  const grams = Number(servingGrams)
  if (Number.isFinite(grams) && grams > 0) {
    const perGram = resolved / grams
    const calorieFree = atwater < ATWATER_MIN_KCAL && resolved < ATWATER_MIN_KCAL
    if ((perGram < MIN_KCAL_PER_GRAM && !calorieFree) || perGram > MAX_KCAL_PER_GRAM) {
      flags.push("implausible-density")
    }
    if (p + c + f > grams) {
      flags.push("macros-exceed-weight")
    }
  }

  return { calories: Math.max(0, resolved), adjusted, flags }
}

// One notch down each confidence ladder we use: the lookup flow's
// official/estimate pair and the high/medium/low scale everywhere else. The
// bottom rung of each ladder (and an absent confidence) stays where it is.
const CONFIDENCE_DOWNGRADE = {
  official: "estimate",
  high: "medium",
  medium: "low",
}

/**
 * Drop a self-reported confidence one notch, for items that failed a check.
 * @param {string|null|undefined} confidence
 * @returns {string|null} the downgraded level, or the input when already at the floor
 */
export const downgradeConfidence = (confidence) =>
  CONFIDENCE_DOWNGRADE[confidence] ?? confidence ?? null
