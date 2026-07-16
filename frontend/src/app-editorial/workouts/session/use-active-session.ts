import * as React from "react"
import { toast } from "sonner"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import {
  rowToSessionWithExercises,
  type SessionWithExercises,
  type SessionExerciseRow,
  type SessionSetRow,
  type WorkoutSessionWithNestedRow,
} from "@/app-editorial/workouts/session/types"

const NESTED_SELECT = "*, session_exercises(*, session_sets(*))"

/** Loads one session (with nested exercises + sets) and exposes the actions
 * needed to log a workout: add/remove exercises, add/update/remove sets, and
 * end the session. Optimistic updates with rollback + toast on error, same
 * shape as use-meals.ts. */
export function useActiveSession(sessionId: string | undefined) {
  const { user } = useAuth()
  const [session, setSession] = React.useState<SessionWithExercises | null>(null)
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  const load = React.useCallback(async () => {
    if (!user || !sessionId) return
    setLoading(true)
    setError(null)
    const { data, error: err } = await supabase
      .from("workout_sessions")
      .select(NESTED_SELECT)
      .eq("id", sessionId)
      .single()

    if (err || !data) {
      setError(err?.message ?? "Session not found.")
      setSession(null)
    } else {
      setSession(rowToSessionWithExercises(data as WorkoutSessionWithNestedRow))
    }
    setLoading(false)
  }, [user, sessionId])

  React.useEffect(() => {
    load()
  }, [load])

  const addExercise = React.useCallback(
    async ({ name, workoutId }: { name: string; workoutId?: string | null }): Promise<boolean> => {
      if (!user || !session) return false
      const tempId = `temp-${crypto.randomUUID()}`
      const position = session.exercises.length
      const optimistic = {
        id: tempId,
        sessionId: session.id,
        userId: user.id,
        workoutId: workoutId ?? null,
        name,
        position,
        createdAt: new Date(),
        sets: [],
      }
      setSession((prev) => (prev ? { ...prev, exercises: [...prev.exercises, optimistic] } : prev))

      const { data, error: err } = await supabase
        .from("session_exercises")
        .insert({
          session_id: session.id,
          user_id: user.id,
          workout_id: workoutId ?? null,
          name,
          position,
        })
        .select("*")
        .single()

      if (err || !data) {
        toast.error("Couldn't add that exercise.")
        setSession((prev) =>
          prev ? { ...prev, exercises: prev.exercises.filter((e) => e.id !== tempId) } : prev
        )
        return false
      }

      const real = data as SessionExerciseRow
      setSession((prev) =>
        prev
          ? {
              ...prev,
              exercises: prev.exercises.map((e) =>
                e.id === tempId
                  ? { ...optimistic, id: real.id, createdAt: new Date(real.created_at) }
                  : e
              ),
            }
          : prev
      )
      return true
    },
    [user, session]
  )

  /** DB delete only — does not touch local state, so the row can morph in
   * place before `dropExercise` removes it. */
  const deleteExercise = React.useCallback(async (exerciseId: string): Promise<boolean> => {
    const { error: err } = await supabase
      .from("session_exercises")
      .delete()
      .eq("id", exerciseId)
    if (err) {
      toast.error("Couldn't remove that exercise.")
    }
    return !err
  }, [])

  const dropExercise = React.useCallback((exerciseId: string) => {
    setSession((prev) =>
      prev
        ? { ...prev, exercises: prev.exercises.filter((e) => e.id !== exerciseId) }
        : prev
    )
  }, [])

  const addSet = React.useCallback(
    async (
      exerciseId: string,
      input: { weight: number | null; reps: number | null; note?: string | null }
    ): Promise<boolean> => {
      if (!user || !session) return false
      const exercise = session.exercises.find((e) => e.id === exerciseId)
      if (!exercise) return false
      const tempId = `temp-${crypto.randomUUID()}`
      const setNumber = exercise.sets.length + 1
      const optimistic = {
        id: tempId,
        sessionExerciseId: exerciseId,
        userId: user.id,
        setNumber,
        weight: input.weight,
        reps: input.reps,
        note: input.note ?? null,
        createdAt: new Date(),
      }

      setSession((prev) =>
        prev
          ? {
              ...prev,
              exercises: prev.exercises.map((e) =>
                e.id === exerciseId ? { ...e, sets: [...e.sets, optimistic] } : e
              ),
            }
          : prev
      )

      const { data, error: err } = await supabase
        .from("session_sets")
        .insert({
          session_exercise_id: exerciseId,
          user_id: user.id,
          set_number: setNumber,
          weight: input.weight,
          reps: input.reps,
          note: input.note ?? null,
        })
        .select("*")
        .single()

      if (err || !data) {
        toast.error("Couldn't log that set.")
        setSession((prev) =>
          prev
            ? {
                ...prev,
                exercises: prev.exercises.map((e) =>
                  e.id === exerciseId
                    ? { ...e, sets: e.sets.filter((s) => s.id !== tempId) }
                    : e
                ),
              }
            : prev
        )
        return false
      }

      const real = data as SessionSetRow
      setSession((prev) =>
        prev
          ? {
              ...prev,
              exercises: prev.exercises.map((e) =>
                e.id === exerciseId
                  ? {
                      ...e,
                      sets: e.sets.map((s) =>
                        s.id === tempId
                          ? { ...optimistic, id: real.id, createdAt: new Date(real.created_at) }
                          : s
                      ),
                    }
                  : e
              ),
            }
          : prev
      )
      return true
    },
    [user, session]
  )

  const updateSet = React.useCallback(
    async (
      setId: string,
      patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>
    ) => {
      let snapshot: SessionWithExercises | null = null
      setSession((prev) => {
        snapshot = prev
        if (!prev) return prev
        return {
          ...prev,
          exercises: prev.exercises.map((e) => ({
            ...e,
            sets: e.sets.map((s) => (s.id === setId ? { ...s, ...patch } : s)),
          })),
        }
      })

      const { error: err } = await supabase.from("session_sets").update(patch).eq("id", setId)
      if (err) {
        toast.error("Couldn't update that set.")
        setSession(snapshot)
      }
    },
    []
  )

  /** DB delete only — does not touch local state, so the row can morph in
   * place before `dropSet` removes it. */
  const deleteSet = React.useCallback(async (setId: string): Promise<boolean> => {
    const { error: err } = await supabase.from("session_sets").delete().eq("id", setId)
    if (err) {
      toast.error("Couldn't remove that set.")
    }
    return !err
  }, [])

  const dropSet = React.useCallback((setId: string) => {
    setSession((prev) => {
      if (!prev) return prev
      return {
        ...prev,
        exercises: prev.exercises.map((e) => ({
          ...e,
          sets: e.sets.filter((s) => s.id !== setId),
        })),
      }
    })
  }, [])

  const endSession = React.useCallback(async (): Promise<boolean> => {
    if (!session) return false
    const endedAt = new Date()
    const durationSeconds = Math.max(
      0,
      Math.round((endedAt.getTime() - session.startedAt.getTime()) / 1000)
    )

    const { error: err } = await supabase
      .from("workout_sessions")
      .update({
        status: "completed",
        ended_at: endedAt.toISOString(),
        duration_seconds: durationSeconds,
      })
      .eq("id", session.id)

    if (err) {
      toast.error("Couldn't end the session.")
      return false
    }

    setSession((prev) =>
      prev
        ? { ...prev, status: "completed", endedAt, durationSeconds }
        : prev
    )
    return true
  }, [session])

  return {
    session,
    loading,
    error,
    reload: load,
    addExercise,
    deleteExercise,
    dropExercise,
    addSet,
    updateSet,
    deleteSet,
    dropSet,
    endSession,
  }
}
