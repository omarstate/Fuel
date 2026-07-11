import * as React from "react"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import {
  rowToSession,
  type WorkoutSession,
  type WorkoutSessionRow,
} from "@/app-editorial/workouts/session/types"

/** The user's most recent in-progress session, if any — powers the "Resume
 * session" banner on the Workouts overview. */
export function useInProgressSession() {
  const { user } = useAuth()
  const [session, setSession] = React.useState<WorkoutSession | null>(null)
  const [loading, setLoading] = React.useState(true)

  const load = React.useCallback(async () => {
    if (!user) return
    setLoading(true)
    const { data } = await supabase
      .from("workout_sessions")
      .select("*")
      .eq("user_id", user.id)
      .eq("status", "in_progress")
      .order("started_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    setSession(data ? rowToSession(data as WorkoutSessionRow) : null)
    setLoading(false)
  }, [user])

  React.useEffect(() => {
    load()
  }, [load])

  return { session, loading, reload: load }
}
