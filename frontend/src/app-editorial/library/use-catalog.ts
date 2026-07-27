import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import { type CatalogMeal } from "@/lib/api"
import { suggestedMealType, type MealType } from "@/app/nutrition/types"

/** How much of a catalog meal to log. `factor` scales the macros; `servingSize`
 * overrides the stored serving text. Omitted = one whole serving, as stored. */
type Portion = { factor: number; servingSize: string | null }

/** Personal-log row shape — mirrors app-editorial/use-meals.ts mealToRow. */
function catalogMealToLogRow(
  meal: CatalogMeal,
  userId: string,
  mealType: MealType,
  portion?: Portion
) {
  const factor = portion?.factor ?? 1
  return {
    id: crypto.randomUUID(),
    user_id: userId,
    name: meal.name,
    meal_type: mealType,
    serving_size: portion ? portion.servingSize : meal.servingSize ?? null,
    calories: Math.round(meal.calories * factor),
    protein: Math.round(meal.protein * factor),
    carbs: Math.round(meal.carbs * factor),
    fat: Math.round(meal.fat * factor),
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
      mealType: MealType = suggestedMealType(),
      portion?: Portion
    ): Promise<boolean> => {
      if (!user) {
        toast.error("Sign in to log meals.")
        return false
      }
      const { error: insertError } = await supabase
        .from("meals")
        .insert(catalogMealToLogRow(meal, user.id, mealType, portion))
      if (insertError) {
        toast.error(`Couldn't add ${meal.name} to today's log.`)
      }
      return !insertError
    },
    [user]
  )
}
