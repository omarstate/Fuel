// Deterministic name matching between a spoken food item and catalog meals.
// Runs AFTER the AI matcher as a safety net: the model matches cross-language
// and fuzzily, but it is occasionally lazy and returns null for an item whose
// name is sitting right there in the catalog. This is plain token containment —
// conservative on purpose, so it never invents a wrong match.
//
// Pure functions, no DB access.

// Filler words that carry no meaning for matching, English + Egyptian Arabic.
const STOPWORDS = new Set([
  "a", "an", "the", "of", "with", "and", "some", "piece", "pieces", "bowl", "plate",
  "cup", "glass", "slice", "slices", "loaf", "loaves",
  "من", "مع", "و", "على", "في", "حبة", "حبتين", "طبق", "كوباية", "كوب", "شريحة", "رغيف",
])

/**
 * Lowercase, unify Arabic letter variants, strip diacritics and anything that
 * isn't a letter or digit. Keeps matching stable across transcription quirks
 * (أ/إ/آ vs ا, ة vs ه, ى vs ي, tatweel, harakat).
 */
export const normalizeMealText = (value) =>
  String(value ?? "")
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/[ىئ]/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()

// Crude English singularizer so "eggs" matches "egg". Arabic plurals are
// irregular enough that we leave them to the AI matcher and aliases.
const singular = (token) => {
  if (token.length > 3 && token.endsWith("es")) return token.slice(0, -2)
  if (token.length > 2 && token.endsWith("s")) return token.slice(0, -1)
  return token
}

/** Significant, normalized, singularized tokens of a name. */
export const mealTokens = (value) => {
  const tokens = new Set()
  for (const raw of normalizeMealText(value).split(" ")) {
    if (!raw || STOPWORDS.has(raw)) continue
    tokens.add(singular(raw))
  }
  return tokens
}

/**
 * Find the catalog meal a spoken item deterministically refers to, or null.
 *
 * A candidate matches when EVERY significant token of one of the item's names
 * (canonical English, Arabic, or the raw spoken words) appears among the
 * candidate's tokens (name + aliases). Generic-to-branded therefore matches
 * ("toast" → "Rich Bake protein toast") but a *qualified* item never matches a
 * candidate missing the qualifier ("skimmed milk" ⊄ "Lamar 0% fat milk").
 * Ties prefer the candidate with the fewest extra tokens (closest name).
 *
 * @param {string[]} itemNames  names to try, most canonical first
 * @param {{ id: string, name: string, aliases?: string[] }[]} candidates
 * @returns {string | null} the matched candidate id
 */
export const matchMealName = (itemNames, candidates) => {
  const nameTokenSets = itemNames
    .map(mealTokens)
    .filter((tokens) => tokens.size > 0)
  if (nameTokenSets.length === 0) return null

  let best = null
  let bestExtra = Infinity

  for (const candidate of candidates) {
    const candidateTokens = mealTokens(
      [candidate.name, ...(candidate.aliases ?? [])].join(" ")
    )
    if (candidateTokens.size === 0) continue

    for (const tokens of nameTokenSets) {
      let contained = true
      for (const token of tokens) {
        if (!candidateTokens.has(token)) {
          contained = false
          break
        }
      }
      if (!contained) continue

      const extra = candidateTokens.size - tokens.size
      if (extra < bestExtra) {
        best = candidate.id
        bestExtra = extra
      }
      break
    }
  }

  return best
}

/**
 * Work out a serving multiplier from a spoken quantity and the catalog's
 * serving-size text, for matches the AI didn't provide a factor for. Handles
 * the two shapes we can be sure about: "1 <unit>" catalog servings scale by
 * count ("3 slices" of "1 slice" → 3), and metric servings scale by ratio
 * ("200 ml" of "100ml" → 2). Anything murkier stays at 1.
 */
export const deriveFactor = (quantity, unit, servingSize) => {
  if (!Number.isFinite(quantity) || quantity <= 0 || !servingSize) return 1

  const serving = normalizeMealText(servingSize)
  const metric = /^(\d+(?:\.\d+)?) ?(ml|g|مل|جم|جرام)/.exec(serving)
  const normalizedUnit = normalizeMealText(unit ?? "")

  if (metric && ["ml", "g", "مل", "جم", "جرام"].includes(normalizedUnit)) {
    const base = Number(metric[1])
    if (Number.isFinite(base) && base > 0) {
      return Math.min(Math.max(quantity / base, 0.1), 20)
    }
  }

  // "1 egg (50g)", "2 eggs", "١ رغيف" — a per-piece serving scales by the
  // count of pieces it covers: spoken "3 eggs" against "2 eggs" → 1.5. Metric
  // servings ("100 g") were handled above and must not be read as piece counts.
  if (!metric && Number.isInteger(quantity)) {
    const pieces = /^([0-9٠-٩]+) /.exec(serving)
    if (pieces) {
      const base = Number(pieces[1].replace(/[٠-٩]/g, (d) => "٠١٢٣٤٥٦٧٨٩".indexOf(d)))
      if (Number.isFinite(base) && base > 0) {
        return Math.min(Math.max(quantity / base, 0.1), 20)
      }
    }
  }

  return 1
}
