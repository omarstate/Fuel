// Deterministic name matching between a spoken exercise and catalog workouts.
// Runs AFTER the AI matcher as a safety net: the model matches cross-language
// and fuzzily, but it is occasionally lazy and returns null for an exercise
// whose name is sitting right there in the catalog. This is plain token
// containment plus the Egyptian lexicon — conservative on purpose, so it never
// invents a wrong match.
//
// Deliberately a sibling of match-meal-name.js rather than a shared import: the
// stopword list, the Arabic-Indic digit folding and the lexicon hop are all
// exercise-specific, and the meal matcher must not drift when this one changes.
//
// Pure functions, no DB access.

import { canonicalExerciseName } from "./exercise-lexicon.js"

// Words that carry no meaning when naming an exercise, English + Egyptian
// Arabic. "في" is stripped because it is the multiplier word ("تمانين في
// تمانية"), not part of any exercise name.
const STOPWORDS = new Set([
  "a", "an", "the", "of", "with", "and", "on", "at", "for", "by",
  "exercise", "workout", "set", "sets", "rep", "reps", "kilo", "kilos", "kg", "lb", "lbs",
  "تمرين", "تمرينة", "تمارين", "مجموعة", "مجموعات", "عدة", "عدات", "تكرار", "تكرارات",
  "كيلو", "كجم", "في", "و", "على", "من", "مع",
])

/**
 * Lowercase, fold Arabic-Indic digits to Western ones, unify Arabic letter
 * variants, strip diacritics and anything that isn't a letter or digit. Keeps
 * matching stable across transcription quirks (أ/إ/آ vs ا, ة vs ه, ى vs ي,
 * tatweel, harakat) and across "٨٠" vs "80".
 */
export const normalizeExerciseText = (value) =>
  String(value ?? "")
    .toLowerCase()
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/[ىئ]/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()

// Crude English singularizer so "curls" matches "curl". Arabic plurals are
// irregular enough that we leave them to the AI matcher and aliases.
const singular = (token) => {
  if (token.length > 3 && token.endsWith("es")) return token.slice(0, -2)
  if (token.length > 2 && token.endsWith("s")) return token.slice(0, -1)
  return token
}

/** Significant, normalized, singularized tokens of an exercise name. */
export const exerciseTokens = (value) => {
  const tokens = new Set()
  for (const raw of normalizeExerciseText(value).split(" ")) {
    if (!raw || STOPWORDS.has(raw)) continue
    // Bare numbers are weights and reps, never part of a name.
    if (/^\d+$/.test(raw)) continue
    tokens.add(singular(raw))
  }
  return tokens
}

// Token sets to try for one spoken name: the words as said, and — when the
// lexicon recognizes them — the canonical English name they stand for. The
// second set is what lets "بنش برس" match a catalog row called "Bench Press"
// before any alias has been learned.
const nameTokenSets = (value) => {
  const sets = []
  const spokenTokens = exerciseTokens(value)
  if (spokenTokens.size > 0) sets.push(spokenTokens)

  const canonical = canonicalExerciseName(value)
  if (canonical) {
    const canonicalTokens = exerciseTokens(canonical)
    if (canonicalTokens.size > 0) sets.push(canonicalTokens)
  }

  return sets
}

// Everything a candidate can be called: its catalog name, its learned aliases,
// and the canonical English name the lexicon maps its name to (which matters
// for rows a user created under an Arabic name).
const candidateTokens = (candidate) => {
  const parts = [candidate.name, ...(candidate.aliases ?? [])]
  const canonical = canonicalExerciseName(candidate.name)
  if (canonical) parts.push(canonical)
  return exerciseTokens(parts.join(" "))
}

/**
 * Find the catalog workout a spoken exercise deterministically refers to, or
 * null.
 *
 * A candidate matches when EVERY significant token of one of the spoken names
 * (canonical English, Arabic, or the raw spoken words — or the lexicon's
 * canonical form of any of them) appears among the candidate's tokens (name +
 * aliases + lexicon canonical). Ties prefer the candidate with the fewest extra
 * tokens; if two different candidates tie on that, this name is genuinely
 * ambiguous and we move on to the next one rather than guess. Returns null when
 * nothing is confident — a wrong exercise is worse than an unmatched one.
 *
 * @param {(string|null|undefined)[]} spokenNames  names to try, most canonical first
 * @param {{ id: string, name: string, aliases?: string[] }[]} candidates
 * @returns {string | null} the matched candidate id
 */
export const matchWorkoutName = (spokenNames, candidates) => {
  const tried = new Set()

  for (const spokenName of spokenNames ?? []) {
    if (!spokenName) continue
    const key = normalizeExerciseText(spokenName)
    if (!key || tried.has(key)) continue
    tried.add(key)

    for (const tokens of nameTokenSets(spokenName)) {
      let best = null
      let bestExtra = Infinity
      let torn = false

      for (const candidate of candidates ?? []) {
        const available = candidateTokens(candidate)
        if (available.size === 0) continue

        let contained = true
        for (const token of tokens) {
          if (!available.has(token)) {
            contained = false
            break
          }
        }
        if (!contained) continue

        const extra = available.size - tokens.size
        if (extra < bestExtra) {
          best = candidate.id
          bestExtra = extra
          torn = false
        } else if (extra === bestExtra && candidate.id !== best) {
          torn = true
        }
      }

      if (best && !torn) return best
    }
  }

  return null
}
