import * as React from "react"
import { useParams, useNavigate } from "react-router-dom"
import { motion } from "framer-motion"
import { toast } from "sonner"
import { ArrowLeft, Square, Plus, Dumbbell } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { MorphButton, type MorphStatus } from "@/components/ui/morph-button"
import { ConfirmDialog } from "@/app-editorial/library/confirm-dialog"
import { editorialAccent, editorialAccentInk } from "@/app-editorial/theme"
import { useActiveSession } from "@/app-editorial/workouts/session/use-active-session"
import { ActiveExerciseCard } from "@/app-editorial/workouts/session/active-exercise-card"
import { SessionStats } from "@/app-editorial/workouts/session/session-stats"
import { RestTimerBar, useRestTimer } from "@/app-editorial/workouts/session/rest-timer"
import { SessionTimer } from "@/app-editorial/workouts/session/session-timer"
import { getWorkouts, type Workout } from "@/lib/api"

/** Rotating milestone messages, fired every 5 logged sets. */
const SET_MILESTONES = [
  "sets down — momentum is real 💪",
  "sets. You're a machine ⚙️",
  "sets in — most people quit before this 🔥",
  "sets. Certified workhorse 🏋️",
]

function AddExerciseControl({
  categorySlug,
  onAdd,
}: {
  categorySlug: string | null
  onAdd: (input: { name: string; workoutId?: string | null }) => Promise<boolean>
}) {
  const [catalog, setCatalog] = React.useState<Workout[]>([])
  const [loading, setLoading] = React.useState(false)
  const [customName, setCustomName] = React.useState("")
  const [status, setStatus] = React.useState<MorphStatus>("idle")

  React.useEffect(() => {
    if (!categorySlug) return
    let active = true
    setLoading(true)
    getWorkouts({ category: categorySlug })
      .then((workouts) => {
        if (active) setCatalog(workouts)
      })
      .catch(() => {
        if (active) toast.error("Couldn't load workouts for this type.")
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [categorySlug])

  async function submitCustom(e: React.FormEvent) {
    e.preventDefault()
    if (status !== "idle") return
    const name = customName.trim()
    if (!name) return
    setStatus("loading")
    const ok = await onAdd({ name, workoutId: null })
    setStatus(ok ? "success" : "error")
    setTimeout(() => {
      setStatus("idle")
      if (ok) setCustomName("")
    }, 1300)
  }

  return (
    <div className="rounded-xl border border-dashed border-border bg-card/60 p-5">
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
        Add exercise
      </div>

      {loading ? (
        <div className="mt-3 flex flex-wrap gap-2">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-8 w-24 animate-pulse rounded-full bg-muted" />
          ))}
        </div>
      ) : catalog.length > 0 ? (
        <div className="mt-3 flex flex-wrap gap-2">
          {catalog.map((w) => (
            <button
              key={w.id}
              type="button"
              onClick={() => onAdd({ name: w.name, workoutId: w.id })}
              className="rounded-full border border-border bg-card px-3.5 py-2.5 text-sm text-foreground transition-colors hover:border-[var(--accent-ink)]/40 hover:bg-[var(--accent-tint)] sm:py-1.5"
            >
              {w.name}
            </button>
          ))}
        </div>
      ) : null}

      <form onSubmit={submitCustom} className="mt-3 flex gap-2">
        <Input
          placeholder="Custom exercise name"
          value={customName}
          onChange={(e) => setCustomName(e.target.value)}
          className="h-11 text-base sm:h-9 sm:text-sm"
        />
        <MorphButton
          type="submit"
          status={status}
          onClick={() => {}}
          disabled={!customName.trim()}
          idleLabel="Add"
          idleIcon={Plus}
          loadingLabel="Adding…"
          successLabel="Added"
        />
      </form>
    </div>
  )
}

/** Full-screen, no-sidebar active-session page. Rendered OUTSIDE
 * AppShellEditorial (see App.tsx), so it applies the editorial light theme +
 * workouts accent itself, the same way app-shell.tsx does for the shell. */
export function SessionActive() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const {
    session,
    loading,
    error,
    addExercise,
    deleteExercise,
    dropExercise,
    addSet,
    updateSet,
    deleteSet,
    dropSet,
    endSession,
  } = useActiveSession(id)
  const [confirmEndOpen, setConfirmEndOpen] = React.useState(false)
  const restTimer = useRestTimer()

  React.useEffect(() => {
    const root = document.documentElement
    root.classList.add("theme-fuel-light")
    return () => root.classList.remove("theme-fuel-light")
  }, [])

  const accent = editorialAccent.workouts
  const themeVars = {
    "--primary": accent,
    "--primary-foreground": "#14120f",
    "--ring": accent,
    "--accent-ink": editorialAccentInk.workouts,
    "--accent-tint": `${accent}24`,
  } as React.CSSProperties

  async function handleEnd(): Promise<boolean> {
    return endSession()
  }

  const totalSets = session?.exercises.reduce((sum, e) => sum + e.sets.length, 0) ?? 0
  const totalVolume =
    session?.exercises.reduce(
      (sum, e) =>
        sum + e.sets.reduce((v, s) => v + (s.weight ?? 0) * (s.reps ?? 0), 0),
      0
    ) ?? 0

  /** Log a set, then start the rest countdown and fire milestone toasts. */
  const handleLogSet = React.useCallback(
    async (
      exerciseId: string,
      input: { weight: number | null; reps: number | null; note: string | null }
    ): Promise<boolean> => {
      // Session best is checked against the state BEFORE this set lands.
      const prevMax =
        session?.exercises.reduce(
          (max, e) => e.sets.reduce((m, s) => Math.max(m, s.weight ?? 0), max),
          0
        ) ?? 0
      const prevSets = totalSets

      const ok = await addSet(exerciseId, input)
      if (!ok) return false

      restTimer.start()

      if ((input.weight ?? 0) > prevMax && prevMax > 0) {
        toast.success(`New session best — ${input.weight} kg 🏆`)
      } else {
        const nextSets = prevSets + 1
        if (nextSets > 0 && nextSets % 5 === 0) {
          const msg = SET_MILESTONES[(nextSets / 5 - 1) % SET_MILESTONES.length]
          toast.success(`${nextSets} ${msg}`)
        }
      }
      return true
    },
    [session, totalSets, addSet, restTimer]
  )

  return (
    <div style={themeVars} className="relative min-h-svh overflow-x-clip bg-background text-foreground">
      {/* breathing accent glow — subtle "session is live" energy */}
      <motion.div
        aria-hidden
        animate={{ opacity: [0.4, 0.9, 0.4] }}
        transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
        className="pointer-events-none absolute -top-28 left-1/2 h-64 w-[36rem] -translate-x-1/2 rounded-full bg-[var(--accent-tint)] blur-3xl"
      />
      <div className="mx-auto flex min-h-svh max-w-3xl flex-col gap-6 px-4 py-6 pb-28 sm:px-10 sm:py-8 sm:pb-28">
        {/* top bar */}
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-border pb-5">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => navigate("/dashboard/workouts")}
              className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground sm:py-1.5 sm:text-xs"
            >
              <ArrowLeft className="size-4 sm:size-3.5" /> Minimize
            </button>
            <div>
              <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--accent-ink)]">
                {session?.categoryName ?? "Session"}
              </div>
              <h1 className="flex items-center gap-2 font-heading text-2xl font-semibold tracking-tight text-foreground">
                <motion.span
                  aria-hidden
                  animate={{ opacity: [1, 0.25, 1], scale: [1, 0.8, 1] }}
                  transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
                  className="size-2.5 rounded-full bg-[var(--accent-ink)]"
                />
                In progress
              </h1>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {session && (
              <div className="text-right">
                <div className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
                  Elapsed
                </div>
                <SessionTimer
                  startedAt={session.startedAt}
                  className="font-mono text-2xl font-semibold tabular-nums text-foreground"
                />
              </div>
            )}
            <Button
              type="button"
              onClick={() => setConfirmEndOpen(true)}
              disabled={!session}
              className="h-10 sm:h-8"
            >
              <Square className="size-3.5" /> End session
            </Button>
          </div>
        </header>

        {/* live stats */}
        {session && (
          <SessionStats
            exercises={session.exercises.length}
            sets={totalSets}
            volumeKg={Math.round(totalVolume)}
          />
        )}

        {/* body */}
        <section className="flex flex-1 flex-col gap-4 pb-10">
          {error ? (
            <div className="rounded-xl border border-border bg-card px-6 py-14 text-center text-sm text-muted-foreground">
              {error}
            </div>
          ) : loading || !session ? (
            <div className="h-40 animate-pulse rounded-xl border border-border bg-muted" />
          ) : (
            <>
              {session.exercises.length === 0 ? (
                <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-border bg-card px-6 py-14 text-center">
                  <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
                    <Dumbbell className="size-5" />
                  </span>
                  <div className="font-medium text-foreground">Log your first exercise</div>
                  <p className="max-w-xs text-sm text-muted-foreground">
                    Pick one below or type a custom name to get started.
                  </p>
                </div>
              ) : (
                <div className="flex flex-col gap-4">
                  {session.exercises.map((exercise) => (
                    <ActiveExerciseCard
                      key={exercise.id}
                      exercise={exercise}
                      onLogSet={(input) => handleLogSet(exercise.id, input)}
                      onUpdateSet={updateSet}
                      onDeleteSet={deleteSet}
                      onDropSet={dropSet}
                      onDeleteExercise={() => deleteExercise(exercise.id)}
                      onDropExercise={() => dropExercise(exercise.id)}
                    />
                  ))}
                </div>
              )}

              <AddExerciseControl categorySlug={session.categorySlug} onAdd={addExercise} />
            </>
          )}
        </section>
      </div>

      <RestTimerBar timer={restTimer} />

      <ConfirmDialog
        open={confirmEndOpen}
        onOpenChange={setConfirmEndOpen}
        title="End this session?"
        message="This marks the session complete and takes you to the summary. You can't resume it afterward."
        onConfirm={() => {}}
        confirmSlot={
          <MorphButton
            idleLabel="End session"
            loadingLabel="Finishing…"
            successLabel="Saved"
            onAction={handleEnd}
            onSuccess={() => {
              setConfirmEndOpen(false)
              if (id) navigate(`/dashboard/workouts/history/${id}`)
            }}
          />
        }
      />
    </div>
  )
}

export default SessionActive
