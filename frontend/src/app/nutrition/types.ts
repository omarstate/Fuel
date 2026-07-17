export type MealType = "breakfast" | "lunch" | "dinner" | "snack"

export type Meal = {
  id: string
  name: string
  mealType: MealType
  servingSize?: string
  calories: number
  protein: number
  carbs: number
  fat: number
  loggedAt: Date
}

export const mealTypeLabel: Record<MealType, string> = {
  breakfast: "Breakfast",
  lunch: "Lunch",
  dinner: "Dinner",
  snack: "Snack",
}

/** Smart default section by local time of day. */
export function suggestedMealType(date = new Date()): MealType {
  const h = date.getHours()
  if (h >= 4 && h < 11) return "breakfast"
  if (h >= 11 && h < 16) return "lunch"
  if (h >= 16 && h < 22) return "dinner"
  return "snack"
}

export const MEAL_TYPE_ORDER: MealType[] = ["breakfast", "lunch", "dinner", "snack"]
