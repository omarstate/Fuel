import { motion } from "framer-motion"
import type { Workout } from "@/lib/api"

export function WorkoutCard({ workout, delay = 0 }: { workout: Workout; delay?: number }) {
  const setsReps =
    workout.targetSets && workout.targetReps
      ? `${workout.targetSets} × ${workout.targetReps}`
      : workout.targetReps ?? (workout.targetSets ? `${workout.targetSets} sets` : null)

  const metaLine = [workout.primaryMuscle, workout.equipment].filter(Boolean).join(" · ")

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay }}
      className="flex flex-col justify-between gap-4 rounded-xl border border-border bg-card p-5"
    >
      <div>
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="truncate text-[0.95rem] font-medium text-foreground">
              {workout.name}
            </div>
            {metaLine && (
              <div className="mt-0.5 font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
                {metaLine}
              </div>
            )}
          </div>
          {setsReps && (
            <span className="shrink-0 rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-[var(--accent-ink)]">
              {setsReps}
            </span>
          )}
        </div>

        {workout.description && (
          <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">{workout.description}</p>
        )}
      </div>

      {workout.categories.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {workout.categories.map((c) => (
            <span
              key={c.id}
              className="rounded-full border border-border px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-muted-foreground"
            >
              {c.name}
            </span>
          ))}
        </div>
      )}
    </motion.div>
  )
}
