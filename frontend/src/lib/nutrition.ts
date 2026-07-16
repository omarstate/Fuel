// Personal-data -> daily calorie/macro target math, mirrored from the
// backend's authoritative implementation at backend/src/utils/compute-targets.js.
// Keep the two in sync — the backend is the source of truth (it's what
// actually persists targets); this copy exists so the onboarding/profile UI
// can show a live preview without round-tripping to the API on every keystroke.

export type Sex = "male" | "female"

export type ActivityLevel = "sedentary" | "light" | "moderate" | "very" | "extra"

export type Pace = "mild" | "standard" | "aggressive"

export type ProfileInput = {
  sex: Sex
  age: number
  heightCm: number
  weightKg: number
  goalWeightKg: number
  activityLevel: ActivityLevel
  pace: Pace
}

export type Targets = {
  calories: number
  protein: number
  carbs: number
  fat: number
}

// Today's hardcoded goals — used as the fallback until a profile exists.
export const DEFAULT_TARGETS: Targets = { calories: 2200, protein: 165, carbs: 220, fat: 70 }

const ACTIVITY_MULTIPLIERS: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  very: 1.725,
  extra: 1.9,
}

const PACE_MAGNITUDES: Record<Pace, number> = {
  mild: 250,
  standard: 500,
  aggressive: 750,
}

const CALORIE_FLOOR = 1200
const MAINTAIN_DEAD_BAND_KG = 0.5

const roundToNearest10 = (value: number) => Math.round(value / 10) * 10

const computeBmr = ({ sex, age, heightCm, weightKg }: ProfileInput) => {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age
  return sex === "male" ? base + 5 : base - 161
}

type Direction = "cut" | "bulk" | "maintain"

const computeDirection = ({ weightKg, goalWeightKg }: ProfileInput): Direction => {
  if (goalWeightKg <= weightKg - MAINTAIN_DEAD_BAND_KG) return "cut"
  if (goalWeightKg >= weightKg + MAINTAIN_DEAD_BAND_KG) return "bulk"
  return "maintain"
}

export function computeTargets(input: ProfileInput): Targets {
  const bmr = computeBmr(input)
  const tdee = bmr * ACTIVITY_MULTIPLIERS[input.activityLevel]

  const direction = computeDirection(input)
  const paceMagnitude = PACE_MAGNITUDES[input.pace]

  let rawCalories = tdee
  if (direction === "cut") rawCalories = tdee - paceMagnitude
  if (direction === "bulk") rawCalories = tdee + paceMagnitude

  const flooredCalories = Math.max(rawCalories, CALORIE_FLOOR)
  const calories = roundToNearest10(flooredCalories)

  const protein = Math.round(1.8 * input.weightKg)
  const fat = Math.round((0.25 * calories) / 9)
  const carbs = Math.max(0, Math.round((calories - protein * 4 - fat * 9) / 4))

  return { calories, protein, carbs, fat }
}

export const ACTIVITY_OPTIONS: { value: ActivityLevel; label: string; hint: string }[] = [
  { value: "sedentary", label: "Sedentary", hint: "Little or no exercise" },
  { value: "light", label: "Lightly active", hint: "Light exercise 1–3 days/week" },
  { value: "moderate", label: "Moderately active", hint: "Moderate exercise 3–5 days/week" },
  { value: "very", label: "Very active", hint: "Hard exercise 6–7 days/week" },
  { value: "extra", label: "Extra active", hint: "Physical job or training twice a day" },
]

export const PACE_OPTIONS: { value: Pace; label: string; hint: string }[] = [
  { value: "mild", label: "Mild", hint: "≈0.25 kg/week" },
  { value: "standard", label: "Standard", hint: "≈0.5 kg/week" },
  { value: "aggressive", label: "Aggressive", hint: "≈0.75 kg/week" },
]
