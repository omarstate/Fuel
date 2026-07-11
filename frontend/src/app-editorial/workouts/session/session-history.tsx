import { Link } from "react-router-dom"
import { motion } from "framer-motion"
import { Dumbbell, Layers, Clock, ChevronRight, RotateCcw } from "lucide-react"
import { useSessionHistory } from "@/app-editorial/workouts/session/use-session-history"
import { formatDuration } from "@/app-editorial/workouts/session/session-timer"
import type { HistorySession } from "@/app-editorial/workouts/session/types"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function formatDay(date: Date) {
  return date.toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  })
}

function formatTime(date: Date) {
  return date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
}

function SessionCard({ session, delay }: { session: HistorySession; delay: number }) {
  const duration = session.durationSeconds != null ? formatDuration(session.durationSeconds) : "—"

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay }}
    >
      <Link
        to={`/dashboard/workouts/history/${session.id}`}
        className="group flex items-center justify-between gap-4 rounded-xl border border-border bg-card p-5 transition-colors hover:border-[var(--accent-ink)]/40 hover:bg-[var(--accent-tint)]/40"
      >
        <div className="flex min-w-0 flex-col gap-1.5">
          <div className="flex items-center gap-2">
            <span className="rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-[var(--accent-ink)]">
              {session.categoryName ?? "Session"}
            </span>
            <span className="font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
              {formatDay(session.startedAt)} · {formatTime(session.startedAt)}
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 font-mono text-xs text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <Clock className="size-3.5" /> {duration}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Dumbbell className="size-3.5" /> {session.exerciseCount}{" "}
              {session.exerciseCount === 1 ? "exercise" : "exercises"}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Layers className="size-3.5" /> {session.setCount}{" "}
              {session.setCount === 1 ? "set" : "sets"}
            </span>
          </div>
        </div>
        <ChevronRight className="size-5 shrink-0 text-muted-foreground transition-colors group-hover:text-[var(--accent-ink)]" />
      </Link>
    </motion.div>
  )
}

/** "My Workouts" — the last 30 days of completed sessions, most recent first.
 * Each card opens the read-only session detail. Lives inside the editorial
 * shell (route /dashboard/workouts/history). */
export function SessionHistory() {
  const { sessions, loading, error, reload } = useSessionHistory()

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Workouts · History
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            My workouts
          </h1>
          <p className="mt-1.5 max-w-md text-sm text-muted-foreground">
            Every session you've completed in the last 30 days. Open one to see it
            exactly as you logged it.
          </p>
        </div>
      </motion.header>

      <motion.section {...fade(0.05)} className="flex flex-col gap-3">
        {error ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <Dumbbell className="size-5" />
            </span>
            <div className="font-medium text-foreground">Couldn't load your history</div>
            <button
              type="button"
              onClick={() => reload()}
              className="mt-1 inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted"
            >
              <RotateCcw className="size-4" /> Retry
            </button>
          </div>
        ) : loading ? (
          <div className="flex flex-col gap-3">
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                className="h-24 animate-pulse rounded-xl border border-border bg-muted"
                style={{ opacity: 1 - i * 0.2 }}
              />
            ))}
          </div>
        ) : sessions.length === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <Dumbbell className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">No sessions in the last 30 days</div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Start a session from the Workouts overview and it'll show up here.
              </p>
            </div>
            <Link
              to="/dashboard/workouts"
              className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              Go to Workouts
            </Link>
          </div>
        ) : (
          sessions.map((session, i) => (
            <SessionCard key={session.id} session={session} delay={Math.min(i, 8) * 0.03} />
          ))
        )}
      </motion.section>
    </div>
  )
}

export default SessionHistory
