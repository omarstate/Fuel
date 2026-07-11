import * as React from "react"
import {
  getWorkoutCategories,
  getWorkoutsGrouped,
  createWorkout as createWorkoutApi,
  type WorkoutCategory,
  type GroupedWorkouts,
} from "@/lib/api"

export function useWorkouts() {
  const [grouped, setGrouped] = React.useState<GroupedWorkouts>([])
  const [categories, setCategories] = React.useState<WorkoutCategory[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)

  const refresh = React.useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [groupedWorkouts, cats] = await Promise.all([
        getWorkoutsGrouped(),
        getWorkoutCategories(),
      ])
      setGrouped(groupedWorkouts)
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

  const createWorkout = React.useCallback(
    async (input: {
      name: string
      description?: string
      categoryIds: string[]
      primaryMuscle?: string
      equipment?: string
      targetSets?: number
      targetReps?: string
    }) => {
      const workout = await createWorkoutApi(input)
      await refresh()
      return workout
    },
    [refresh]
  )

  return { grouped, categories, loading, error, refresh, createWorkout }
}
