import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import type { Meal, MealType } from "@/app/nutrition/types"
import { startOfDay, dayKey } from "@/app-editorial/day-bounds"

type MealRow = {
  id: string
  user_id: string
  name: string
  meal_type: MealType
  serving_size: string | null
  calories: number
  protein: number
  carbs: number
  fat: number
  logged_at: string
}

function rowToMeal(row: MealRow): Meal {
  return {
    id: row.id,
    name: row.name,
    mealType: row.meal_type,
    servingSize: row.serving_size ?? undefined,
    calories: row.calories,
    protein: row.protein,
    carbs: row.carbs,
    fat: row.fat,
    loggedAt: new Date(row.logged_at),
  }
}

export type DayTotals = { calories: number; protein: number; carbs: number; fat: number }

export type MealHistoryDay = {
  key: string
  date: Date
  meals: Meal[]
  totals: DayTotals
}

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

function groupByDay(meals: Meal[]): MealHistoryDay[] {
  const groups = new Map<string, Meal[]>()
  for (const meal of meals) {
    const key = dayKey(meal.loggedAt)
    const bucket = groups.get(key)
    if (bucket) bucket.push(meal)
    else groups.set(key, [meal])
  }

  return Array.from(groups.entries())
    .map(([key, dayMeals]) => ({
      key,
      date: startOfDay(dayMeals[0].loggedAt),
      meals: dayMeals,
      totals: dayMeals.reduce(
        (acc, m) => ({
          calories: acc.calories + m.calories,
          protein: acc.protein + m.protein,
          carbs: acc.carbs + m.carbs,
          fat: acc.fat + m.fat,
        }),
        { calories: 0, protein: 0, carbs: 0, fat: 0 }
      ),
    }))
    .sort((a, b) => b.date.getTime() - a.date.getTime())
}

/** Last 30 days of logged meals, grouped by local calendar day (most recent
 * first) — the "what did I eat" history behind /dashboard/nutrition/history. */
export function useMealHistory() {
  const { user } = useAuth()
  const [days, setDays] = React.useState<MealHistoryDay[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  const load = React.useCallback(async () => {
    if (!user) return
    setLoading(true)
    setError(null)
    const since = new Date(Date.now() - THIRTY_DAYS_MS).toISOString()

    const { data, error: err } = await supabase
      .from("meals")
      .select("*")
      .eq("user_id", user.id)
      .gte("logged_at", since)
      .order("logged_at", { ascending: false })

    if (err) {
      setError(err.message)
      toast.error("Couldn't load your meal history.")
    } else {
      setDays(groupByDay((data as MealRow[]).map(rowToMeal)))
    }
    setLoading(false)
  }, [user])

  React.useEffect(() => {
    load()
  }, [load])

  const removeMeal = React.useCallback(async (id: string) => {
    let snapshot: MealHistoryDay[] = []
    setDays((prev) => {
      snapshot = prev
      return prev
        .map((day) => ({ ...day, meals: day.meals.filter((m) => m.id !== id) }))
        .filter((day) => day.meals.length > 0)
    })
    const { error: err } = await supabase.from("meals").delete().eq("id", id)
    if (err) {
      toast.error("Couldn't delete that meal.")
      setDays(snapshot)
    }
  }, [])

  return { days, loading, error, reload: load, removeMeal }
}
