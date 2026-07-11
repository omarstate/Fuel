import { Link, useParams } from "react-router-dom"
import { motion } from "framer-motion"
import { ArrowLeft, CalendarDays, Clock, Dumbbell, Layers } from "lucide-react"
import { StatCard } from "@/app-editorial/stat-card"
import { useActiveSession } from "@/app-editorial/workouts/session/use-active-session"
import { SessionExerciseList } from "@/app-editorial/workouts/session/session-exercise-list"
import { formatDuration } from "@/app-editorial/workouts/session/session-timer"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function formatDate(date: Date) {
  return date.toLocaleDateString(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
    year: "numeric",
  })
}

function formatTime(date: Date) {
  return date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
}

function BackLink() {
  return (
    <Link
      to="/dashboard/workouts/history"
      className="inline-flex w-fit items-center gap-1.5 font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground transition-colors hover:text-foreground"
    >
      <ArrowLeft className="size-3.5" /> My Workouts
    </Link>
  )
}

/** Read-only view of a completed session — the exact layout the user saw while
 * training, rendered with SessionExerciseList in non-editable mode. Lives
 * inside the editorial shell (route /dashboard/workouts/history/:id). */
export function SessionDetail() {
  const { id } = useParams<{ id: string }>()
  const { session, loading, error } = useActiveSession(id)

  if (loading) {
    return (
      <div className="mx-auto flex max-w-3xl flex-col gap-6">
        <div className="h-4 w-28 animate-pulse rounded bg-muted" />
        <div className="flex flex-col gap-2 border-b border-border pb-6">
          <div className="h-4 w-32 animate-pulse rounded bg-muted" />
          <div className="h-10 w-1/2 animate-pulse rounded bg-muted" />
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-24 animate-pulse rounded-xl border border-border bg-muted" />
          ))}
        </div>
        <div className="h-40 animate-pulse rounded-xl border border-border bg-muted" />
      </div>
    )
  }

  if (error || !session) {
    return (
      <div className="mx-auto flex max-w-3xl flex-col gap-6">
        <BackLink />
        <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
          <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
            <Dumbbell className="size-5" />
          </span>
          <div>
            <div className="font-medium text-foreground">Session not found</div>
            <p className="mt-1 max-w-sm text-sm text-muted-foreground">
              This session may have been removed, or the link is out of date.
            </p>
          </div>
          <Link
            to="/dashboard/workouts/history"
            className="mt-1 inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted"
          >
            Back to My Workouts
          </Link>
        </div>
      </div>
    )
  }

  const totalSets = session.exercises.reduce((sum, e) => sum + e.sets.length, 0)
  const duration =
    session.durationSeconds != null
      ? formatDuration(session.durationSeconds)
      : session.endedAt
        ? formatDuration((session.endedAt.getTime() - session.startedAt.getTime()) / 1000)
        : "—"

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <motion.div {...fade()}>
        <BackLink />
      </motion.div>

      <motion.header {...fade(0.05)} className="flex flex-col gap-2 border-b border-border pb-6">
        <span className="w-fit rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-[var(--accent-ink)]">
          {session.categoryName ?? "Session"}
        </span>
        <h1 className="font-heading text-4xl font-semibold tracking-tight text-foreground">
          {formatDate(session.startedAt)}
        </h1>
        <p className="text-sm text-muted-foreground">
          Started {formatTime(session.startedAt)}
          {session.endedAt ? ` · finished ${formatTime(session.endedAt)}` : ""}
        </p>
      </motion.header>

      <motion.section {...fade(0.1)} className="grid gap-4 sm:grid-cols-3">
        <StatCard icon={Clock} label="Duration" value={duration} />
        <StatCard icon={Dumbbell} label="Exercises" value={session.exercises.length} />
        <StatCard icon={Layers} label="Sets logged" value={totalSets} />
      </motion.section>

      <motion.section {...fade(0.15)} className="flex flex-col gap-4 pb-6">
        {session.exercises.length === 0 ? (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <CalendarDays className="size-5" />
            </span>
            <div className="font-medium text-foreground">No exercises were logged</div>
            <p className="max-w-xs text-sm text-muted-foreground">
              This session was ended without logging any exercises.
            </p>
          </div>
        ) : (
          <SessionExerciseList exercises={session.exercises} editable={false} />
        )}
      </motion.section>
    </div>
  )
}

export default SessionDetail
