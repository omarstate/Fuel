import * as React from "react"
import { useParams, useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { ArrowLeft, Square, Plus, Dumbbell } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { ConfirmDialog } from "@/app-editorial/library/confirm-dialog"
import { editorialAccent, editorialAccentInk } from "@/app-editorial/theme"
import { useActiveSession } from "@/app-editorial/workouts/session/use-active-session"
import { SessionExerciseList } from "@/app-editorial/workouts/session/session-exercise-list"
import { SessionTimer } from "@/app-editorial/workouts/session/session-timer"
import { getWorkouts, type Workout } from "@/lib/api"

function AddExerciseControl({
  categorySlug,
  onAdd,
}: {
  categorySlug: string | null
  onAdd: (input: { name: string; workoutId?: string | null }) => void
}) {
  const [catalog, setCatalog] = React.useState<Workout[]>([])
  const [loading, setLoading] = React.useState(false)
  const [customName, setCustomName] = React.useState("")

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

  function submitCustom(e: React.FormEvent) {
    e.preventDefault()
    const name = customName.trim()
    if (!name) return
    onAdd({ name, workoutId: null })
    setCustomName("")
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
              className="rounded-full border border-border bg-card px-3 py-1.5 text-sm text-foreground transition-colors hover:border-[var(--accent-ink)]/40 hover:bg-[var(--accent-tint)]"
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
          className="h-9"
        />
        <Button type="submit" disabled={!customName.trim()}>
          <Plus /> Add
        </Button>
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
    removeExercise,
    addSet,
    updateSet,
    removeSet,
    endSession,
  } = useActiveSession(id)
  const [confirmEndOpen, setConfirmEndOpen] = React.useState(false)
  const [ending, setEnding] = React.useState(false)

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

  async function handleEnd() {
    setEnding(true)
    const ok = await endSession()
    setEnding(false)
    if (ok && id) {
      setConfirmEndOpen(false)
      navigate(`/dashboard/workouts/history/${id}`)
    }
  }

  const totalSets = session?.exercises.reduce((sum, e) => sum + e.sets.length, 0) ?? 0

  return (
    <div style={themeVars} className="min-h-svh bg-background text-foreground">
      <div className="mx-auto flex min-h-svh max-w-3xl flex-col gap-6 px-6 py-8 sm:px-10">
        {/* top bar */}
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-border pb-5">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => navigate("/dashboard/workouts")}
              className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:text-foreground"
            >
              <ArrowLeft className="size-3.5" /> Minimize
            </button>
            <div>
              <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--accent-ink)]">
                {session?.categoryName ?? "Session"}
              </div>
              <h1 className="font-heading text-2xl font-semibold tracking-tight text-foreground">
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
            <Button type="button" onClick={() => setConfirmEndOpen(true)} disabled={!session}>
              <Square className="size-3.5" /> End session
            </Button>
          </div>
        </header>

        {/* counter strip */}
        {session && (
          <section className="grid grid-cols-2 gap-4">
            <div className="rounded-xl border border-border bg-card p-4">
              <div className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
                Exercises
              </div>
              <div className="mt-1 font-mono text-2xl font-semibold text-foreground">
                {session.exercises.length}
              </div>
            </div>
            <div className="rounded-xl border border-border bg-card p-4">
              <div className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
                Sets logged
              </div>
              <div className="mt-1 font-mono text-2xl font-semibold text-foreground">
                {totalSets}
              </div>
            </div>
          </section>
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
                <SessionExerciseList
                  exercises={session.exercises}
                  editable
                  onAddSet={addSet}
                  onUpdateSet={updateSet}
                  onRemoveSet={removeSet}
                  onRemoveExercise={removeExercise}
                />
              )}

              <AddExerciseControl categorySlug={session.categorySlug} onAdd={addExercise} />
            </>
          )}
        </section>
      </div>

      <ConfirmDialog
        open={confirmEndOpen}
        onOpenChange={setConfirmEndOpen}
        title="End this session?"
        message="This marks the session complete and takes you to the summary. You can't resume it afterward."
        confirmLabel="End session"
        loadingLabel="Ending…"
        loading={ending}
        onConfirm={handleEnd}
      />
    </div>
  )
}

export default SessionActive
