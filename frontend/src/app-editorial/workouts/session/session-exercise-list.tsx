import * as React from "react"
import { motion } from "framer-motion"
import { Trash2, Plus } from "lucide-react"
import { Input } from "@/components/ui/input"
import type { SessionExerciseWithSets, SessionSet } from "@/app-editorial/workouts/session/types"

function SetRow({
  set,
  index,
  editable,
  onUpdate,
  onRemove,
}: {
  set: SessionSet
  index: number
  editable: boolean
  onUpdate?: (patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>) => void
  onRemove?: () => void
}) {
  const [weight, setWeight] = React.useState(set.weight?.toString() ?? "")
  const [reps, setReps] = React.useState(set.reps?.toString() ?? "")
  const [note, setNote] = React.useState(set.note ?? "")

  React.useEffect(() => setWeight(set.weight?.toString() ?? ""), [set.weight])
  React.useEffect(() => setReps(set.reps?.toString() ?? ""), [set.reps])
  React.useEffect(() => setNote(set.note ?? ""), [set.note])

  if (!editable) {
    return (
      <div className="grid grid-cols-[2rem_1fr_1fr_2fr] items-center gap-3 py-2 text-sm">
        <span className="font-mono text-xs text-muted-foreground">#{index + 1}</span>
        <span className="text-foreground">
          {set.weight ?? "—"} <span className="text-xs text-muted-foreground">kg</span>
        </span>
        <span className="text-foreground">
          {set.reps ?? "—"} <span className="text-xs text-muted-foreground">reps</span>
        </span>
        <span className="truncate text-xs text-muted-foreground">{set.note ?? ""}</span>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-[1.25rem_1fr_1fr_auto] items-center gap-2 py-1 sm:grid-cols-[2rem_1fr_1fr_2fr_2rem]">
      <span className="font-mono text-xs text-muted-foreground">#{index + 1}</span>
      <Input
        type="number"
        inputMode="decimal"
        min={0}
        step={0.5}
        placeholder="kg"
        value={weight}
        onChange={(e) => setWeight(e.target.value)}
        onBlur={() => {
          const next = weight.trim() === "" ? null : Number(weight)
          if (next !== set.weight) onUpdate?.({ weight: Number.isNaN(next as number) ? null : next })
        }}
        className="h-11 px-2 text-base sm:h-9 sm:text-sm"
      />
      <Input
        type="number"
        inputMode="numeric"
        min={0}
        placeholder="reps"
        value={reps}
        onChange={(e) => setReps(e.target.value)}
        onBlur={() => {
          const next = reps.trim() === "" ? null : Number(reps)
          if (next !== set.reps) onUpdate?.({ reps: Number.isNaN(next as number) ? null : next })
        }}
        className="h-11 px-2 text-base sm:h-9 sm:text-sm"
      />
      <Input
        placeholder="Note (optional)"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        onBlur={() => {
          const next = note.trim() || null
          if (next !== set.note) onUpdate?.({ note: next })
        }}
        className="hidden h-11 px-2 text-base sm:block sm:h-9 sm:text-sm"
      />
      <button
        type="button"
        aria-label={`Remove set ${index + 1}`}
        onClick={onRemove}
        className="grid size-11 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-destructive sm:size-9"
      >
        <Trash2 className="size-4 sm:size-3.5" />
      </button>
    </div>
  )
}

function AddSetForm({ onAdd }: { onAdd: (input: { weight: number | null; reps: number | null; note: string | null }) => void }) {
  const [weight, setWeight] = React.useState("")
  const [reps, setReps] = React.useState("")
  const [note, setNote] = React.useState("")

  function submit(e: React.FormEvent) {
    e.preventDefault()
    onAdd({
      weight: weight.trim() === "" ? null : Number(weight),
      reps: reps.trim() === "" ? null : Number(reps),
      note: note.trim() || null,
    })
    setWeight("")
    setReps("")
    setNote("")
  }

  return (
    <form
      onSubmit={submit}
      className="grid grid-cols-[1.25rem_1fr_1fr_auto] items-center gap-2 border-t border-dashed border-border pt-2 sm:grid-cols-[2rem_1fr_1fr_2fr_auto]"
    >
      <span className="font-mono text-xs text-muted-foreground">+</span>
      <Input
        type="number"
        inputMode="decimal"
        min={0}
        step={0.5}
        placeholder="kg"
        value={weight}
        onChange={(e) => setWeight(e.target.value)}
        className="h-11 px-2 text-base sm:h-9 sm:text-sm"
      />
      <Input
        type="number"
        inputMode="numeric"
        min={0}
        placeholder="reps"
        value={reps}
        onChange={(e) => setReps(e.target.value)}
        className="h-11 px-2 text-base sm:h-9 sm:text-sm"
      />
      <Input
        placeholder="Note (optional)"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        className="hidden h-11 px-2 text-base sm:block sm:h-9 sm:text-sm"
      />
      <button
        type="submit"
        className="inline-flex h-11 shrink-0 items-center gap-1 rounded-md bg-[var(--accent-tint)] px-3 text-sm font-medium text-[var(--accent-ink)] transition-colors hover:brightness-95 sm:h-9 sm:px-2.5 sm:text-xs"
      >
        <Plus className="size-4 sm:size-3.5" /> Add
      </button>
    </form>
  )
}

/** Renders logged exercises + their sets. Shared between the active-session
 * page (editable) and the session detail page (read-only) so the two look
 * identical. */
export function SessionExerciseList({
  exercises,
  editable,
  onAddSet,
  onUpdateSet,
  onRemoveSet,
  onRemoveExercise,
}: {
  exercises: SessionExerciseWithSets[]
  editable: boolean
  onAddSet?: (
    exerciseId: string,
    input: { weight: number | null; reps: number | null; note: string | null }
  ) => void
  onUpdateSet?: (
    setId: string,
    patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>
  ) => void
  onRemoveSet?: (setId: string) => void
  onRemoveExercise?: (exerciseId: string) => void
}) {
  if (exercises.length === 0) return null

  return (
    <div className="flex flex-col gap-4">
      {exercises.map((exercise, i) => (
        <motion.div
          key={exercise.id}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.25, delay: Math.min(i, 8) * 0.03 }}
          className="rounded-xl border border-border bg-card p-5"
        >
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <h3 className="font-heading text-lg font-semibold tracking-tight text-foreground">
                {exercise.name}
              </h3>
              {exercise.workoutId === null && (
                <span className="rounded-full border border-border px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-muted-foreground">
                  Custom
                </span>
              )}
            </div>
            {editable && (
              <button
                type="button"
                aria-label={`Remove ${exercise.name}`}
                onClick={() => onRemoveExercise?.(exercise.id)}
                className="grid size-9 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-destructive sm:size-7"
              >
                <Trash2 className="size-4 sm:size-3.5" />
              </button>
            )}
          </div>

          <div className="mt-3">
            {exercise.sets.length === 0 ? (
              <p className="py-1 text-xs text-muted-foreground">
                {editable ? "No sets yet — log the first one below." : "No sets logged."}
              </p>
            ) : (
              <div className="flex flex-col divide-y divide-border/60">
                {exercise.sets.map((set, i) => (
                  <SetRow
                    key={set.id}
                    set={set}
                    index={i}
                    editable={editable}
                    onUpdate={(patch) => onUpdateSet?.(set.id, patch)}
                    onRemove={() => onRemoveSet?.(set.id)}
                  />
                ))}
              </div>
            )}

            {editable && (
              <div className="mt-2">
                <AddSetForm onAdd={(input) => onAddSet?.(exercise.id, input)} />
              </div>
            )}
          </div>
        </motion.div>
      ))}
    </div>
  )
}
