// Pure functions: score how well a catalog meal fits the macros the user has
// LEFT for today, and rank a candidate list by that fit. No DB access — this is
// the deterministic backbone that keeps meal suggestions working even when
// Gemini is unavailable, and it's unit-testable in isolation.
//
// score = Σ weight_d * |meal_d − remaining_d| / denom_d   (lower = better)
// where denom_d avoids divide-by-zero via a per-dimension floor, and a meal
// that blows well past the remaining calories is hard-penalized so a slight
// overshoot ("slightly higher, slightly lower") stays fine but a blowout sinks.

const WEIGHTS = { protein: 3, calories: 2, carbs: 1, fat: 1 }
const FLOORS = { calories: 100, protein: 10, carbs: 10, fat: 5 }

// Meals that exceed the remaining calories by more than this fraction get a
// flat penalty added to their score, dropping them to the bottom of the ranking.
const CALORIE_BLOWOUT_RATIO = 1.15
const BLOWOUT_PENALTY = 10

export const scoreMealFit = (meal, remaining) => {
  let score = 0
  for (const key of Object.keys(WEIGHTS)) {
    const denom = Math.max(remaining[key] ?? 0, FLOORS[key])
    score += (WEIGHTS[key] * Math.abs((meal[key] ?? 0) - (remaining[key] ?? 0))) / denom
  }

  if ((meal.calories ?? 0) > (remaining.calories ?? 0) * CALORIE_BLOWOUT_RATIO) {
    score += BLOWOUT_PENALTY
  }

  return score
}

export const rankMealsForRemaining = (meals, remaining, { max = 12 } = {}) =>
  meals
    .map((meal) => ({ meal, score: scoreMealFit(meal, remaining) }))
    .sort((a, b) => a.score - b.score)
    .slice(0, max)
    .map((entry) => entry.meal)
