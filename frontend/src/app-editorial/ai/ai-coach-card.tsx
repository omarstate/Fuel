import * as React from "react"
import { motion } from "framer-motion"
import { RotateCcw, Check, Flame } from "lucide-react"
import { getAiInsights, type AiInsights } from "@/lib/api"
import { cn } from "@/lib/utils"

type State =
  | { kind: "loading" }
  | { kind: "ready"; data: AiInsights }
  | { kind: "error" }
  | { kind: "hidden" }

// The backend returns 503 with a configuration message when GEMINI_API_KEY is
// missing; in that case we hide the card entirely rather than nagging the user.
function isConfigError(message: string): boolean {
  return /configured/i.test(message)
}

export function AiCoachCard() {
  const [state, setState] = React.useState<State>({ kind: "loading" })
  const [refreshing, setRefreshing] = React.useState(false)

  const load = React.useCallback(async (refresh: boolean, active: () => boolean) => {
    try {
      const data = await getAiInsights(refresh)
      if (!active()) return
      setState({ kind: "ready", data })
    } catch (err) {
      if (!active()) return
      const message = err instanceof Error ? err.message : ""
      setState({ kind: isConfigError(message) ? "hidden" : "error" })
    }
  }, [])

  React.useEffect(() => {
    let alive = true
    void load(false, () => alive)
    return () => {
      alive = false
    }
  }, [load])

  async function handleRefresh() {
    if (refreshing) return
    setRefreshing(true)
    await load(true, () => true)
    setRefreshing(false)
  }

  if (state.kind === "hidden") return null

  if (state.kind === "loading") {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="h-3 w-16 animate-pulse rounded bg-muted" />
        <div className="mt-3 h-6 w-2/3 animate-pulse rounded bg-muted" />
        <div className="mt-4 flex flex-col gap-2">
          <div className="h-3 w-full animate-pulse rounded bg-muted" />
          <div className="h-3 w-5/6 animate-pulse rounded bg-muted" />
        </div>
      </div>
    )
  }

  if (state.kind === "error") {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="flex items-center justify-between gap-3">
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Coach
          </div>
          <button
            type="button"
            onClick={handleRefresh}
            disabled={refreshing}
            aria-label="Retry coach insights"
            className="grid size-7 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-50"
          >
            <RotateCcw className={cn("size-3.5", refreshing && "animate-spin")} />
          </button>
        </div>
        <p className="mt-3 text-sm text-muted-foreground">Coach is unavailable right now.</p>
      </div>
    )
  }

  const { data } = state
  const streak = data.facts?.streak?.current ?? 0

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      className="rounded-xl border border-border bg-card p-6"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
              Coach
            </div>
            {streak > 0 && (
              <span className="inline-flex items-center gap-1 rounded-full border border-border bg-background px-2 py-0.5 font-mono text-[0.65rem] text-foreground">
                <Flame className="size-3 text-[var(--accent-ink)]" />
                {streak}-day streak
              </span>
            )}
          </div>
          <h3 className="mt-2 font-heading text-lg font-semibold tracking-tight text-foreground">
            {data.headline}
          </h3>
        </div>
        <button
          type="button"
          onClick={handleRefresh}
          disabled={refreshing}
          aria-label="Refresh coach insights"
          className="grid size-7 shrink-0 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-50"
        >
          <RotateCcw className={cn("size-3.5", refreshing && "animate-spin")} />
        </button>
      </div>

      {data.insights.length > 0 && (
        <div className="mt-4 flex flex-col gap-3">
          {data.insights.map((insight, i) => (
            <div key={i}>
              <div className="text-sm font-semibold text-foreground">{insight.title}</div>
              <p className="mt-0.5 text-sm text-muted-foreground">{insight.body}</p>
            </div>
          ))}
        </div>
      )}

      {data.tips.length > 0 && (
        <ul className="mt-5 flex flex-col gap-2 border-t border-border pt-4">
          {data.tips.map((tip, i) => (
            <li key={i} className="flex items-start gap-2 text-sm text-foreground">
              <Check className="mt-0.5 size-4 shrink-0 text-[var(--accent-ink)]" />
              <span>{tip}</span>
            </li>
          ))}
        </ul>
      )}
    </motion.div>
  )
}
