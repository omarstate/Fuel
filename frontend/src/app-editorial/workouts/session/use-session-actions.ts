import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import type { WorkoutCategory } from "@/lib/api"
import type { WorkoutSessionRow } from "@/app-editorial/workouts/session/types"

/** Session-level actions not tied to a single in-progress session view:
 * starting a brand new one. Used by StartSessionDialog. */
export function useSessionActions() {
  const { user } = useAuth()
  const [starting, setStarting] = React.useState(false)

  const startSession = React.useCallback(
    async (category: WorkoutCategory): Promise<string | null> => {
      if (!user) return null
      setStarting(true)
      try {
        const { data, error } = await supabase
          .from("workout_sessions")
          .insert({
            user_id: user.id,
            category_id: category.id,
            category_name: category.name,
            category_slug: category.slug,
            status: "in_progress",
          })
          .select("*")
          .single()

        if (error || !data) {
          toast.error("Couldn't start that session.")
          return null
        }
        return (data as WorkoutSessionRow).id
      } finally {
        setStarting(false)
      }
    },
    [user]
  )

  return { startSession, starting }
}
