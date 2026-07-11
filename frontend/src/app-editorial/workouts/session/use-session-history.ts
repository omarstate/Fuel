import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import {
  rowToSession,
  type HistorySession,
  type WorkoutSessionRow,
} from "@/app-editorial/workouts/session/types"

type HistoryRow = WorkoutSessionRow & {
  session_exercises: { id: string; session_sets: { id: string }[] | null }[] | null
}

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

/** Completed sessions from the last 30 days, most recent first, enriched
 * with exercise/set counts for the "My Workouts" history list. */
export function useSessionHistory() {
  const { user } = useAuth()
  const [sessions, setSessions] = React.useState<HistorySession[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  const load = React.useCallback(async () => {
    if (!user) return
    setLoading(true)
    setError(null)
    const since = new Date(Date.now() - THIRTY_DAYS_MS).toISOString()

    const { data, error: err } = await supabase
      .from("workout_sessions")
      .select("*, session_exercises(id, session_sets(id))")
      .eq("status", "completed")
      .gte("started_at", since)
      .order("started_at", { ascending: false })

    if (err) {
      setError(err.message)
      toast.error("Couldn't load your workout history.")
    } else {
      const rows = (data ?? []) as HistoryRow[]
      setSessions(
        rows.map((row) => {
          const exercises = row.session_exercises ?? []
          return {
            ...rowToSession(row),
            exerciseCount: exercises.length,
            setCount: exercises.reduce((sum, e) => sum + (e.session_sets?.length ?? 0), 0),
          }
        })
      )
    }
    setLoading(false)
  }, [user])

  React.useEffect(() => {
    load()
  }, [load])

  return { sessions, loading, error, reload: load }
}
