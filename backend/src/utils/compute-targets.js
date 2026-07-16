// Pure function: personal data -> daily calorie + macro targets.
// No DB access. This is the authoritative implementation — the frontend
// keeps a TS mirror in sync at frontend/src/lib/nutrition.ts.

// TDEE = BMR * activity multiplier.
export const ACTIVITY_MULTIPLIERS = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  very: 1.725,
  extra: 1.9,
}

// kcal/day adjustment magnitude by chosen pace.
export const PACE_MAGNITUDES = {
  mild: 250,
  standard: 500,
  aggressive: 750,
}

const CALORIE_FLOOR = 1200
const MAINTAIN_DEAD_BAND_KG = 0.5

const roundToNearest10 = (value) => Math.round(value / 10) * 10

// Mifflin-St Jeor BMR.
const computeBmr = ({ sex, age, heightCm, weightKg }) => {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age
  return sex === "male" ? base + 5 : base - 161
}

// goal vs current weight, with a 0.5 kg dead-band around "maintain".
const computeDirection = ({ weightKg, goalWeightKg }) => {
  if (goalWeightKg <= weightKg - MAINTAIN_DEAD_BAND_KG) return "cut"
  if (goalWeightKg >= weightKg + MAINTAIN_DEAD_BAND_KG) return "bulk"
  return "maintain"
}

export const computeTargets = ({
  sex,
  age,
  heightCm,
  weightKg,
  goalWeightKg,
  activityLevel,
  pace,
}) => {
  const bmr = computeBmr({ sex, age, heightCm, weightKg })
  const tdee = bmr * ACTIVITY_MULTIPLIERS[activityLevel]

  const direction = computeDirection({ weightKg, goalWeightKg })
  const paceMagnitude = PACE_MAGNITUDES[pace]

  let rawCalories = tdee
  if (direction === "cut") rawCalories = tdee - paceMagnitude
  if (direction === "bulk") rawCalories = tdee + paceMagnitude

  const flooredCalories = Math.max(rawCalories, CALORIE_FLOOR)
  const targetCalories = roundToNearest10(flooredCalories)

  const targetProtein = Math.round(1.8 * weightKg)
  const targetFat = Math.round((0.25 * targetCalories) / 9)
  const targetCarbs = Math.max(
    0,
    Math.round((targetCalories - targetProtein * 4 - targetFat * 9) / 4)
  )

  return {
    targetCalories,
    targetProtein,
    targetCarbs,
    targetFat,
  }
}
