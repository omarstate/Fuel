import * as React from "react"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import { addDays, dayKey, startOfDay, msUntilNextMidnight } from "@/app-editorial/day-bounds"

/** One calendar day in the current (Mon-first) week. `logged` distinguishes a
 * day with no meals at all from a day the user genuinely ate very little — so
 * the chart can render "not logged" differently from a real deficit, and the
 * weekly stats can exclude untracked days instead of counting them as zeros. */
export type WeekDay = {
  /** Local YYYY-MM-DD key. */
  key: string
  /** Mon-first index 0..6. */
  index: number
  /** Sum of calories logged that day. */
  calories: number
  /** True once at least one meal exists for the day. */
  logged: boolean
  isToday: boolean
  isFuture: boolean
}

/** Monday (local midnight) of the week containing `date`. */
function startOfWeek(date: Date): Date {
  const d = startOfDay(date)
  const monFirst = (d.getDay() + 6) % 7 // 0 = Mon
  return addDays(d, -monFirst)
}

function emptyWeek(now: Date): WeekDay[] {
  const weekStart = startOfWeek(now)
  const todayIdx = (now.getDay() + 6) % 7
  return Array.from({ length: 7 }, (_, i) => ({
    key: dayKey(addDays(weekStart, i)),
    index: i,
    calories: 0,
    logged: false,
    isToday: i === todayIdx,
    isFuture: i > todayIdx,
  }))
}

/** Per-day calorie totals for the current local week (Mon–Sun), reloading at
 * midnight so an open tab rolls into the new week. Mirrors the day-boundary and
 * reload/guard patterns in `useMeals`. */
export function useWeekMeals() {
  const { user } = useAuth()
  const [days, setDays] = React.useState<WeekDay[]>(() => emptyWeek(new Date()))
  const [loading, setLoading] = React.useState(true)

  const loadTokenRef = React.useRef(0)

  const reload = React.useCallback(() => {
    const userId = user?.id
    if (!userId) return
    const token = loadTokenRef.current
    setLoading(true)

    const now = new Date()
    const weekStart = startOfWeek(now)
    const weekEnd = addDays(weekStart, 7)
    const scaffold = emptyWeek(now)
    const indexByKey = new Map(scaffold.map((d) => [d.key, d.index]))

    supabase
      .from("meals")
      .select("calories, logged_at")
      .eq("user_id", userId)
      .gte("logged_at", weekStart.toISOString())
      .lt("logged_at", weekEnd.toISOString())
      .then(({ data, error }) => {
        if (loadTokenRef.current !== token) return
        if (error) {
          // Non-fatal: the chart just shows an empty week rather than erroring.
          setDays(scaffold)
        } else {
          const next = scaffold.map((d) => ({ ...d }))
          for (const row of data as { calories: number; logged_at: string }[]) {
            const idx = indexByKey.get(dayKey(new Date(row.logged_at)))
            if (idx === undefined) continue
            next[idx].calories += row.calories
            next[idx].logged = true
          }
          setDays(next)
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
      loadTokenRef.current += 1
      clearTimeout(midnightTimer)
    }
  }, [user?.id, reload])

  return { days, loading, reload }
}
