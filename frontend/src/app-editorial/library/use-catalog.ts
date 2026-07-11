import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import {
  getCategories,
  getMealsGrouped,
  createCatalogMeal,
  type Category,
  type CatalogMeal,
  type CreateCatalogMealInput,
  type GroupedCatalog,
} from "@/lib/api"

/** Personal-log row shape — mirrors app-editorial/use-meals.ts mealToRow. */
function catalogMealToLogRow(meal: CatalogMeal, userId: string) {
  return {
    id: crypto.randomUUID(),
    user_id: userId,
    name: meal.name,
    meal_type: "lunch",
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
    async (meal: CatalogMeal) => {
      if (!user) {
        toast.error("Sign in to log meals.")
        return
      }
      const { error: insertError } = await supabase
        .from("meals")
        .insert(catalogMealToLogRow(meal, user.id))
      if (insertError) {
        toast.error(`Couldn't add ${meal.name} to today's log.`)
      } else {
        toast.success(`${meal.name} added to today's log`)
      }
    },
    [user]
  )
}

export function useCatalog() {
  const [grouped, setGrouped] = React.useState<GroupedCatalog>([])
  const [categories, setCategories] = React.useState<Category[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  const refresh = React.useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [groupedCatalog, cats] = await Promise.all([getMealsGrouped(), getCategories()])
      setGrouped(groupedCatalog)
      setCategories(cats)
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.")
    } finally {
      setLoading(false)
    }
  }, [])

  React.useEffect(() => {
    refresh()
  }, [refresh])

  const createMeal = React.useCallback(
    async (input: CreateCatalogMealInput) => {
      const meal = await createCatalogMeal(input)
      await refresh()
      return meal
    },
    [refresh]
  )

  const addCatalogMealToLog = useAddCatalogMealToLog()

  return { grouped, categories, loading, error, refresh, createMeal, addCatalogMealToLog }
}
