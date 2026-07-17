import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import type { Meal, MealType } from "@/app/nutrition/types"
import { addDays, startOfDay, msUntilNextMidnight } from "@/app-editorial/day-bounds"

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

function mealToRow(meal: Meal, userId: string) {
  return {
    id: meal.id,
    user_id: userId,
    name: meal.name,
    meal_type: meal.mealType,
    serving_size: meal.servingSize ?? null,
    calories: meal.calories,
    protein: meal.protein,
    carbs: meal.carbs,
    fat: meal.fat,
    logged_at: meal.loggedAt.toISOString(),
  }
}

/** Today's meal log — scoped to the current local calendar day, so it's
 * always "what I ate today" rather than every meal ever logged. Schedules
 * itself to reload right at midnight so an open tab flips over to the new
 * (empty) day without needing a manual refresh. */
export function useMeals() {
  const { user } = useAuth()
  const [meals, setMeals] = React.useState<Meal[]>([])
  const [loading, setLoading] = React.useState(true)

  // Guards the query result against a user change / unmount landing after the
  // request was fired. Bumped on every effect run and on unmount.
  const loadTokenRef = React.useRef(0)

  /** Stable reload of today's log. Safe to call after out-of-band inserts
   * (e.g. the library picker's direct supabase write) to resync the list. */
  const reload = React.useCallback(() => {
    const userId = user?.id
    if (!userId) return
    const token = loadTokenRef.current
    setLoading(true)
    const dayStart = startOfDay(new Date())
    const dayEnd = addDays(dayStart, 1)

    supabase
      .from("meals")
      .select("*")
      .eq("user_id", userId)
      .gte("logged_at", dayStart.toISOString())
      .lt("logged_at", dayEnd.toISOString())
      .order("logged_at", { ascending: false })
      .then(({ data, error }) => {
        if (loadTokenRef.current !== token) return
        if (error) {
          toast.error("Couldn't load your meals.")
        } else {
          setMeals((data as MealRow[]).map(rowToMeal))
        }
        setLoading(false)
      })
  }, [user?.id])

  React.useEffect(() => {
    if (!user) return
    let midnightTimer: ReturnType<typeof setTimeout>

    const tick = () => {
      reload()
      midnightTimer = setTimeout(tick, msUntilNextMidnight())
    }

    tick()

    return () => {
      // Invalidate any in-flight query and stop the midnight timer.
      loadTokenRef.current += 1
      clearTimeout(midnightTimer)
    }
  }, [user?.id, reload])

  const addMeal = React.useCallback(
    async (meal: Meal): Promise<boolean> => {
      if (!user) return false
      setMeals((prev) => [meal, ...prev]) // optimistic
      const { error } = await supabase.from("meals").insert(mealToRow(meal, user.id))
      if (error) {
        toast.error("Couldn't save that meal.")
        setMeals((prev) => prev.filter((m) => m.id !== meal.id)) // rollback
      }
      return !error
    },
    [user]
  )

  /** DB delete only — does not touch local state, so the row can morph in
   * place before `dropMeal` removes it (see MealRow's inline MorphButton). */
  const deleteMeal = React.useCallback(async (id: string): Promise<boolean> => {
    const { error } = await supabase.from("meals").delete().eq("id", id)
    if (error) {
      toast.error("Couldn't delete that meal.")
    }
    return !error
  }, [])

  const dropMeal = React.useCallback((id: string) => {
    setMeals((prev) => prev.filter((m) => m.id !== id))
  }, [])

  return { meals, loading, addMeal, deleteMeal, dropMeal, reload }
}
