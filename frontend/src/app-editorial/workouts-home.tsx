import { Link } from "react-router-dom"
import { motion } from "framer-motion"
import {
  Dumbbell,
  CalendarDays,
  Clock,
  Layers,
  Play,
  ArrowRight,
  BookOpen,
  ClipboardList,
} from "lucide-react"
import { StatCard } from "@/app-editorial/stat-card"
import { StartSessionDialog } from "@/app-editorial/workouts/session/start-session-dialog"
import { SessionTimer } from "@/app-editorial/workouts/session/session-timer"
import { useInProgressSession } from "@/app-editorial/workouts/session/use-in-progress-session"
import { useSessionHistory } from "@/app-editorial/workouts/session/use-session-history"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

const WEEK_MS = 7 * 24 * 60 * 60 * 1000

function countThisWeek(sessions: { startedAt: Date }[]) {
  const cutoff = Date.now() - WEEK_MS
  return sessions.filter((s) => s.startedAt.getTime() >= cutoff).length
}

function relativeDay(date: Date) {
  const diffDays = Math.floor((Date.now() - date.getTime()) / (24 * 60 * 60 * 1000))
  if (diffDays <= 0) return "Today"
  if (diffDays === 1) return "Yesterday"
  if (diffDays < 7) return `${diffDays}d ago`
  const weeks = Math.floor(diffDays / 7)
  return `${weeks}w ago`
}

export function WorkoutsHome() {
  const today = new Date().toLocaleDateString(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  })
  const { session: inProgress } = useInProgressSession()
  const { sessions } = useSessionHistory()

  const thisWeek = countThisWeek(sessions)
  const lastSession = sessions[0] ?? null

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            {today}
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            Workouts
          </h1>
        </div>
        <Link
          to="/dashboard/workouts/history"
          className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-3.5 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted"
        >
          <ClipboardList className="size-4" /> My workouts
        </Link>
      </motion.header>

      {/* Resume banner */}
      {inProgress && (
        <motion.div {...fade(0.03)}>
          <Link
            to={`/dashboard/workouts/session/${inProgress.id}`}
            className="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-[var(--accent-ink)]/30 bg-[var(--accent-tint)] p-5 transition-colors hover:brightness-[0.98]"
          >
            <div className="flex items-center gap-3">
              <span className="grid size-10 place-items-center rounded-xl bg-background/70 text-[var(--accent-ink)]">
                <Play className="size-4" />
              </span>
              <div>
                <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--accent-ink)]">
                  Session in progress
                </div>
                <div className="font-heading text-lg font-semibold tracking-tight text-foreground">
                  {inProgress.categoryName ?? "Workout"} · resume
                </div>
              </div>
            </div>
            <SessionTimer
              startedAt={inProgress.startedAt}
              className="font-mono text-xl font-semibold tabular-nums text-[var(--accent-ink)]"
            />
          </Link>
        </motion.div>
      )}

      {/* Hero: Start a new session — the main act */}
      <motion.section {...fade(0.05)}>
        <div className="relative overflow-hidden rounded-2xl border border-border bg-card p-8 sm:p-10">
          <div
            className="pointer-events-none absolute -right-16 -top-16 size-64 rounded-full opacity-40 blur-3xl"
            style={{ background: "var(--accent-tint)" }}
          />
          <div className="relative flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
            <div className="max-w-lg">
              <span className="grid size-12 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
                <Dumbbell className="size-6" />
              </span>
              <h2 className="mt-5 font-heading text-3xl font-semibold tracking-tight text-foreground">
                Start a new session
              </h2>
              <p className="mt-2 text-muted-foreground">
                Pick what you're training today — push, pull, legs, or anything from
                your library — and we'll start the clock and log every set.
              </p>
            </div>
            <StartSessionDialog
              trigger={
                <button
                  type="button"
                  className="group inline-flex shrink-0 items-center gap-2.5 rounded-xl bg-[#14120f] px-6 py-4 text-base font-semibold text-[#f7f3ea] shadow-sm transition-all hover:bg-[#2a251d] hover:shadow-md"
                >
                  <Play className="size-5 transition-transform group-hover:scale-110" />
                  Start session
                </button>
              }
            />
          </div>
        </div>
      </motion.section>

      {/* Stats */}
      <motion.section {...fade(0.1)} className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard icon={CalendarDays} label="Sessions" value={thisWeek} hint="This week" />
        <StatCard icon={Layers} label="Sessions" value={sessions.length} hint="Last 30 days" />
        <StatCard
          icon={Clock}
          label="Last session"
          value={lastSession ? relativeDay(lastSession.startedAt) : "—"}
          hint={lastSession?.categoryName ?? "No sessions yet"}
        />
        <StatCard
          icon={Dumbbell}
          label="Last type"
          value={lastSession?.categoryName ?? "—"}
        />
      </motion.section>

      {/* Secondary links */}
      <motion.section {...fade(0.15)} className="grid gap-4 sm:grid-cols-2">
        <Link
          to="/dashboard/workouts/history"
          className="group flex items-center justify-between gap-3 rounded-xl border border-border bg-card p-5 transition-colors hover:bg-muted"
        >
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <ClipboardList className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">My workouts</div>
              <p className="text-sm text-muted-foreground">Your last 30 days of sessions</p>
            </div>
          </div>
          <ArrowRight className="size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
        </Link>

        <Link
          to="/dashboard/workouts/library"
          className="group flex items-center justify-between gap-3 rounded-xl border border-border bg-card p-5 transition-colors hover:bg-muted"
        >
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <BookOpen className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">Workout library</div>
              <p className="text-sm text-muted-foreground">Browse & build your exercises</p>
            </div>
          </div>
          <ArrowRight className="size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
        </Link>
      </motion.section>
    </div>
  )
}
