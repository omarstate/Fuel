import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import { type CatalogMeal } from "@/lib/api"
import { suggestedMealType, type MealType } from "@/app/nutrition/types"

/** Personal-log row shape — mirrors app-editorial/use-meals.ts mealToRow. */
function catalogMealToLogRow(meal: CatalogMeal, userId: string, mealType: MealType) {
  return {
    id: crypto.randomUUID(),
    user_id: userId,
    name: meal.name,
    meal_type: mealType,
    serving_size: meal.servingSize ?? null,
    calories: meal.calories,
    protein: meal.protein,
    carbs: meal.carbs,
    fat: meal.fat,
    logged_at: new Date().toISOString(),
    catalog_meal_id: meal.id,
  }
}

/** Insert a catalog meal into today's personal log. Shared by the library and My Meals pages. */
export function useAddCatalogMealToLog() {
  const { user } = useAuth()
  return React.useCallback(
    async (
      meal: CatalogMeal,
      mealType: MealType = suggestedMealType()
    ): Promise<boolean> => {
      if (!user) {
        toast.error("Sign in to log meals.")
        return false
      }
      const { error: insertError } = await supabase
        .from("meals")
        .insert(catalogMealToLogRow(meal, user.id, mealType))
      if (insertError) {
        toast.error(`Couldn't add ${meal.name} to today's log.`)
      }
      return !insertError
    },
    [user]
  )
}
