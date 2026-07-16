import * as React from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Trash2, Plus } from "lucide-react"
import { Input } from "@/components/ui/input"
import { MorphButton } from "@/components/ui/morph-button"
import type { SessionExerciseWithSets, SessionSet } from "@/app-editorial/workouts/session/types"

function SetRow({
  set,
  index,
  editable,
  onUpdate,
  onDelete,
  onDropped,
}: {
  set: SessionSet
  index: number
  editable: boolean
  onUpdate?: (patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>) => void
  onDelete?: () => Promise<boolean>
  onDropped?: () => void
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
      <MorphButton
        variant="inline"
        intent="destructive"
        idleIcon={Trash2}
        idleLabel={`Remove set ${index + 1}`}
        successLabel="Removed"
        onAction={onDelete}
        onSuccess={onDropped}
        className="size-11 sm:size-9"
      />
    </div>
  )
}

function AddSetForm({
  onAdd,
}: {
  onAdd: (input: { weight: number | null; reps: number | null; note: string | null }) => Promise<boolean>
}) {
  const [weight, setWeight] = React.useState("")
  const [reps, setReps] = React.useState("")
  const [note, setNote] = React.useState("")
  const [status, setStatus] = React.useState<"idle" | "loading" | "success" | "error">("idle")

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    if (status !== "idle") return
    setStatus("loading")
    const ok = await onAdd({
      weight: weight.trim() === "" ? null : Number(weight),
      reps: reps.trim() === "" ? null : Number(reps),
      note: note.trim() || null,
    })
    setStatus(ok ? "success" : "error")
    setTimeout(() => {
      setStatus("idle")
      if (ok) {
        setWeight("")
        setReps("")
        setNote("")
      }
    }, 900)
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
      <MorphButton
        type="submit"
        status={status}
        onClick={() => {}}
        idleIcon={Plus}
        idleLabel="Add set"
        loadingLabel="Logging…"
        successLabel="Logged"
        resetDelay={900}
        className="h-11 sm:h-9"
      />
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
  onDeleteSet,
  onDropSet,
  onDeleteExercise,
  onDropExercise,
}: {
  exercises: SessionExerciseWithSets[]
  editable: boolean
  onAddSet?: (
    exerciseId: string,
    input: { weight: number | null; reps: number | null; note: string | null }
  ) => Promise<boolean>
  onUpdateSet?: (
    setId: string,
    patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>
  ) => void
  /** DB delete only — returns success so the row can morph before it's dropped. */
  onDeleteSet?: (setId: string) => Promise<boolean>
  /** Drops the set from local state, called after the success beat. */
  onDropSet?: (setId: string) => void
  onDeleteExercise?: (exerciseId: string) => Promise<boolean>
  onDropExercise?: (exerciseId: string) => void
}) {
  if (exercises.length === 0) return null

  return (
    <div className="flex flex-col gap-4">
      <AnimatePresence initial={false}>
        {exercises.map((exercise, i) => (
          <motion.div
            key={exercise.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, height: 0, marginTop: 0 }}
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
                <MorphButton
                  variant="inline"
                  intent="destructive"
                  idleIcon={Trash2}
                  idleLabel={`Remove ${exercise.name}`}
                  successLabel="Removed"
                  onAction={() => onDeleteExercise?.(exercise.id) ?? Promise.resolve(false)}
                  onSuccess={() => onDropExercise?.(exercise.id)}
                />
              )}
            </div>

            <div className="mt-3">
              {exercise.sets.length === 0 ? (
                <p className="py-1 text-xs text-muted-foreground">
                  {editable ? "No sets yet — log the first one below." : "No sets logged."}
                </p>
              ) : (
                <div className="flex flex-col divide-y divide-border/60">
                  <AnimatePresence initial={false}>
                    {exercise.sets.map((set, i) => (
                      <motion.div
                        key={set.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0, height: 0, marginTop: 0 }}
                        transition={{ duration: 0.2 }}
                      >
                        <SetRow
                          set={set}
                          index={i}
                          editable={editable}
                          onUpdate={(patch) => onUpdateSet?.(set.id, patch)}
                          onDelete={() => onDeleteSet?.(set.id) ?? Promise.resolve(false)}
                          onDropped={() => onDropSet?.(set.id)}
                        />
                      </motion.div>
                    ))}
                  </AnimatePresence>
                </div>
              )}

              {editable && (
                <div className="mt-2">
                  <AddSetForm
                    onAdd={(input) => onAddSet?.(exercise.id, input) ?? Promise.resolve(false)}
                  />
                </div>
              )}
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}
