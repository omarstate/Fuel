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
