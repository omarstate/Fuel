import * as React from "react"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import { addDays, dayKey, startOfDay, msUntilNextMidnight } from "@/app-editorial/day-bounds"

/** How far back to look when counting streaks. A streak can't exceed this. */
const HISTORY_DAYS = 180
/** A day counts toward the goal streak if within this fraction of the target. */
const GOAL_BAND = 0.1

/** Length of the run of consecutive local days ending at today (or yesterday,
 * so a not-yet-finished today doesn't break a live streak) for which `qualifies`
 * holds. Walking local calendar days keeps this consistent with the rest of the
 * editorial app's day boundaries. */
function currentStreak(qualifies: Set<string>, today: Date): number {
  let cursor = today
  if (!qualifies.has(dayKey(cursor))) {
    cursor = addDays(cursor, -1)
    if (!qualifies.has(dayKey(cursor))) return 0
  }
  let n = 0
  while (qualifies.has(dayKey(cursor))) {
    n += 1
    cursor = addDays(cursor, -1)
  }
  return n
}

/**
 * Two streaks derived from meal history:
 *  - `logging`: consecutive days with any meal logged (the habit streak).
 *  - `goal`: consecutive days whose calories landed within GOAL_BAND of target
 *    (the results streak). Today is only *required* to qualify once it's over —
 *    an in-progress day below goal keeps the streak alive via yesterday.
 */
export function useStreaks(goalCalories: number) {
  const { user } = useAuth()
  const [streaks, setStreaks] = React.useState({ logging: 0, goal: 0 })
  const [loading, setLoading] = React.useState(true)
  const loadTokenRef = React.useRef(0)

  const reload = React.useCallback(() => {
    const userId = user?.id
    if (!userId) return
    const token = loadTokenRef.current
    setLoading(true)

    const now = new Date()
    const since = addDays(startOfDay(now), -HISTORY_DAYS)

    supabase
      .from("meals")
      .select("calories, logged_at")
      .eq("user_id", userId)
      .gte("logged_at", since.toISOString())
      .then(({ data, error }) => {
        if (loadTokenRef.current !== token) return
        if (error || !data) {
          setStreaks({ logging: 0, goal: 0 })
          setLoading(false)
          return
        }

        const perDay = new Map<string, number>()
        for (const row of data as { calories: number; logged_at: string }[]) {
          const k = dayKey(new Date(row.logged_at))
          perDay.set(k, (perDay.get(k) ?? 0) + row.calories)
        }

        const loggedDays = new Set(perDay.keys())
        const goalDays = new Set(
          [...perDay.entries()]
            .filter(([, kcal]) => Math.abs(kcal - goalCalories) <= goalCalories * GOAL_BAND)
            .map(([k]) => k)
        )

        setStreaks({
          logging: currentStreak(loggedDays, now),
          goal: currentStreak(goalDays, now),
        })
        setLoading(false)
      })
  }, [user?.id, goalCalories])

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

  return { logging: streaks.logging, goal: streaks.goal, loading }
}
