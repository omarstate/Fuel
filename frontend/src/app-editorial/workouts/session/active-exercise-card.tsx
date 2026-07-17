import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { Trash2, Check } from "lucide-react"
import { Input } from "@/components/ui/input"
import { MorphButton } from "@/components/ui/morph-button"
import { cn } from "@/lib/utils"
import { SetLogger } from "@/app-editorial/workouts/session/set-logger"
import type { SessionExerciseWithSets, SessionSet } from "@/app-editorial/workouts/session/types"

const fmtWeight = (w: number) => (Number.isInteger(w) ? String(w) : w.toFixed(1))

function SetPill({
  set,
  index,
  selected,
  onClick,
}: {
  set: SessionSet
  index: number
  selected: boolean
  onClick: () => void
}) {
  return (
    <motion.button
      type="button"
      onClick={onClick}
      layout
      initial={{ scale: 0.5, opacity: 0 }}
      animate={{ scale: 1, opacity: 1 }}
      exit={{ scale: 0.5, opacity: 0 }}
      transition={{ type: "spring", stiffness: 500, damping: 30 }}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border px-3 py-2 font-mono text-sm tabular-nums transition-colors",
        selected
          ? "border-[var(--accent-ink)]/50 bg-[var(--accent-tint)] text-foreground"
          : "border-border bg-card text-foreground hover:border-[var(--accent-ink)]/30"
      )}
    >
      <span className="text-[0.65rem] text-muted-foreground">#{index + 1}</span>
      <span className="font-semibold">
        {set.weight !== null ? fmtWeight(set.weight) : "BW"}
        <span className="mx-0.5 text-muted-foreground">×</span>
        {set.reps ?? "—"}
      </span>
      {set.note && <span className="size-1.5 rounded-full bg-[var(--accent-ink)]" />}
    </motion.button>
  )
}

/** Inline editor for a tapped set pill — edit weight/reps/note, or delete. */
function SetEditor({
  set,
  index,
  onUpdate,
  onDelete,
  onDropped,
  onClose,
}: {
  set: SessionSet
  index: number
  onUpdate: (patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>) => void
  onDelete: () => Promise<boolean>
  onDropped: () => void
  onClose: () => void
}) {
  return (
    <motion.div
      initial={{ opacity: 0, height: 0 }}
      animate={{ opacity: 1, height: "auto" }}
      exit={{ opacity: 0, height: 0 }}
      transition={{ duration: 0.2 }}
      className="overflow-hidden"
    >
      <div className="mt-2 flex flex-wrap items-center gap-2 rounded-xl border border-[var(--accent-ink)]/30 bg-[var(--accent-tint)]/40 p-2.5">
        <span className="font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground">
          Set #{index + 1}
        </span>
        <Input
          key={`w-${set.id}`}
          type="number"
          inputMode="decimal"
          min={0}
          step={0.5}
          placeholder="kg"
          defaultValue={set.weight ?? ""}
          onBlur={(e) => {
            const next = e.target.value.trim() === "" ? null : Number(e.target.value)
            if (next !== set.weight) onUpdate({ weight: Number.isNaN(next as number) ? null : next })
          }}
          className="h-10 w-20 px-2 text-base sm:h-9 sm:text-sm"
        />
        <Input
          key={`r-${set.id}`}
          type="number"
          inputMode="numeric"
          min={0}
          placeholder="reps"
          defaultValue={set.reps ?? ""}
          onBlur={(e) => {
            const next = e.target.value.trim() === "" ? null : Number(e.target.value)
            if (next !== set.reps) onUpdate({ reps: Number.isNaN(next as number) ? null : next })
          }}
          className="h-10 w-20 px-2 text-base sm:h-9 sm:text-sm"
        />
        <Input
          key={`n-${set.id}`}
          placeholder="Note"
          defaultValue={set.note ?? ""}
          onBlur={(e) => {
            const next = e.target.value.trim() || null
            if (next !== set.note) onUpdate({ note: next })
          }}
          className="h-10 min-w-24 flex-1 px-2 text-base sm:h-9 sm:text-sm"
        />
        <MorphButton
          variant="inline"
          intent="destructive"
          idleIcon={Trash2}
          idleLabel={`Delete set ${index + 1}`}
          successLabel="Removed"
          onAction={onDelete}
          onSuccess={() => {
            onDropped()
            onClose()
          }}
          className="size-10 sm:size-9"
        />
        <button
          type="button"
          onClick={onClose}
          aria-label="Done editing"
          className="grid size-10 place-items-center rounded-lg border border-border bg-card text-muted-foreground transition-colors hover:text-foreground sm:size-9"
        >
          <Check className="size-4" />
        </button>
      </div>
    </motion.div>
  )
}

/** Editable exercise card for the live session: compact tappable set pills +
 * the quick stepper logger. The read-only history view keeps using
 * SessionExerciseList — this card is active-session only. */
export function ActiveExerciseCard({
  exercise,
  onLogSet,
  onUpdateSet,
  onDeleteSet,
  onDropSet,
  onDeleteExercise,
  onDropExercise,
}: {
  exercise: SessionExerciseWithSets
  onLogSet: (input: { weight: number | null; reps: number | null; note: string | null }) => Promise<boolean>
  onUpdateSet: (
    setId: string,
    patch: Partial<{ weight: number | null; reps: number | null; note: string | null }>
  ) => void
  onDeleteSet: (setId: string) => Promise<boolean>
  onDropSet: (setId: string) => void
  onDeleteExercise: () => Promise<boolean>
  onDropExercise: () => void
}) {
  const [selectedSetId, setSelectedSetId] = React.useState<string | null>(null)
  const lastSet = exercise.sets.at(-1) ?? null
  const selected = exercise.sets.find((s) => s.id === selectedSetId) ?? null
  const selectedIndex = selected ? exercise.sets.indexOf(selected) : -1

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, height: 0, marginTop: 0 }}
      transition={{ duration: 0.25 }}
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
          {exercise.sets.length > 0 && (
            <span className="rounded-full bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.6rem] font-semibold uppercase tracking-wide text-[var(--accent-ink)]">
              {exercise.sets.length} {exercise.sets.length === 1 ? "set" : "sets"}
            </span>
          )}
        </div>
        <MorphButton
          variant="inline"
          intent="destructive"
          idleIcon={Trash2}
          idleLabel={`Remove ${exercise.name}`}
          successLabel="Removed"
          onAction={onDeleteExercise}
          onSuccess={onDropExercise}
        />
      </div>

      {exercise.sets.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-1.5">
          <AnimatePresence initial={false}>
            {exercise.sets.map((set, i) => (
              <SetPill
                key={set.id}
                set={set}
                index={i}
                selected={set.id === selectedSetId}
                onClick={() => setSelectedSetId((cur) => (cur === set.id ? null : set.id))}
              />
            ))}
          </AnimatePresence>
        </div>
      )}

      <AnimatePresence>
        {selected && (
          <SetEditor
            key={selected.id}
            set={selected}
            index={selectedIndex}
            onUpdate={(patch) => onUpdateSet(selected.id, patch)}
            onDelete={() => onDeleteSet(selected.id)}
            onDropped={() => onDropSet(selected.id)}
            onClose={() => setSelectedSetId(null)}
          />
        )}
      </AnimatePresence>

      <div className="mt-4 border-t border-dashed border-border pt-3">
        <SetLogger
          key={exercise.id}
          defaultWeight={lastSet?.weight ?? null}
          defaultReps={lastSet?.reps ?? null}
          onLog={onLogSet}
        />
      </div>
    </motion.div>
  )
}
