import * as React from "react"
import { motion } from "framer-motion"
import { RotateCcw, Check } from "lucide-react"
import { AddToLogButton } from "@/app-editorial/add-to-log-button"
import { suggestMeals, type SuggestResponse } from "@/lib/api"
import { cn } from "@/lib/utils"

type Remaining = { calories: number; protein: number; carbs: number; fat: number }

type State =
  | { kind: "loading" }
  | { kind: "ready"; data: SuggestResponse }
  | { kind: "error" }
  | { kind: "hidden" }

// The backend returns 503 with a configuration message when Supabase isn't
// configured; in that case we hide the card rather than nagging the user. Same
// heuristic as ai-coach-card.
function isConfigError(message: string): boolean {
  return /configured/i.test(message)
}

// ---------------------------------------------------------------------------
// Bucketed module cache (quota control). Rather than key on the exact remaining
// macros — which change on every log — we bucket them, so many nearby states
// share one cached answer. 10-minute TTL. A manual refresh bypasses it.
// ---------------------------------------------------------------------------
const CACHE_TTL_MS = 10 * 60 * 1000

type CacheEntry = { at: number; data: SuggestResponse }
const suggestCache = new Map<string, CacheEntry>()

function bucketKey(r: Remaining): string {
  return `${Math.floor(r.calories / 100)}|${Math.floor(r.protein / 10)}|${Math.floor(
    r.carbs / 15
  )}|${Math.floor(r.fat / 10)}`
}

function MacroTrio({ protein, carbs, fat }: { protein: number; carbs: number; fat: number }) {
  return (
    <div className="flex items-center gap-x-2.5 font-mono text-xs whitespace-nowrap text-muted-foreground">
      <span>
        <span className="text-[#b5431c]">P</span> {protein}
      </span>
      <span>
        <span className="text-[#a9781f]">C</span> {carbs}
      </span>
      <span>
        <span className="text-[#69762d]">F</span> {fat}
      </span>
    </div>
  )
}

export function MealSuggestionsCard({
  remaining,
  ready,
  onLogged,
}: {
  remaining: Remaining
  ready: boolean
  onLogged: () => void
}) {
  const [state, setState] = React.useState<State>({ kind: "loading" })
  const [refreshing, setRefreshing] = React.useState(false)
  // Stale-response guard: only the latest request may write state.
  const requestIdRef = React.useRef(0)

  const key = bucketKey(remaining)

  const load = React.useCallback(
    async (r: Remaining, force: boolean, active: () => boolean) => {
      const cacheK = bucketKey(r)

      if (!force) {
        const cached = suggestCache.get(cacheK)
        if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
          setState({ kind: "ready", data: cached.data })
          return
        }
      }

      const requestId = requestIdRef.current + 1
      requestIdRef.current = requestId
      setState({ kind: "loading" })
      try {
        const data = await suggestMeals(r)
        if (!active() || requestIdRef.current !== requestId) return
        suggestCache.set(cacheK, { at: Date.now(), data })
        setState({ kind: "ready", data })
      } catch (err) {
        if (!active() || requestIdRef.current !== requestId) return
        const message = err instanceof Error ? err.message : ""
        setState({ kind: isConfigError(message) ? "hidden" : "error" })
      }
    },
    []
  )

  // Fetch on mount and whenever the remaining bucket changes — but not until the
  // meals have finished loading, so `remaining` reflects the real day.
  React.useEffect(() => {
    if (!ready) return
    let alive = true
    void load(remaining, false, () => alive)
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, key, load])

  async function handleRefresh() {
    if (refreshing) return
    setRefreshing(true)
    await load(remaining, true, () => true)
    setRefreshing(false)
  }

  if (state.kind === "hidden") return null

  if (!ready || state.kind === "loading") {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="h-3 w-16 animate-pulse rounded bg-muted" />
        <div className="mt-3 h-6 w-2/3 animate-pulse rounded bg-muted" />
        <div className="mt-5 flex flex-col gap-4">
          {[0, 1, 2].map((i) => (
            <div key={i} className="flex flex-col gap-2" style={{ opacity: 1 - i * 0.2 }}>
              <div className="h-4 w-1/2 animate-pulse rounded bg-muted" />
              <div className="h-3 w-3/4 animate-pulse rounded bg-muted" />
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (state.kind === "error") {
    return (
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="flex items-center justify-between gap-3">
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Up next
          </div>
          <button
            type="button"
            onClick={handleRefresh}
            disabled={refreshing}
            aria-label="Retry meal suggestions"
            className="grid size-7 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-50"
          >
            <RotateCcw className={cn("size-3.5", refreshing && "animate-spin")} />
          </button>
        </div>
        <p className="mt-3 text-sm text-muted-foreground">
          Couldn't load suggestions right now.
        </p>
      </div>
    )
  }

  const { data } = state

  if (data.targetReached) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="rounded-xl border border-border bg-card p-6"
      >
        <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
          Up next
        </div>
        <div className="mt-3 flex items-center gap-2">
          <span className="grid size-6 place-items-center rounded-full bg-[var(--accent-tint)] text-[var(--accent-ink)]">
            <Check className="size-3.5" />
          </span>
          <p className="text-sm text-foreground">Target hit — nothing left to fill today.</p>
        </div>
      </motion.div>
    )
  }

  const basis = `Left today: ${remaining.calories} kcal · ${remaining.protein} g P · ${remaining.carbs} g C · ${remaining.fat} g F`

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      className="rounded-xl border border-border bg-card p-6"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Up next
          </div>
          <h3 className="mt-2 font-heading text-lg font-semibold tracking-tight text-foreground">
            What fits your day
          </h3>
          <p className="mt-1 font-mono text-xs text-muted-foreground">{basis}</p>
        </div>
        <button
          type="button"
          onClick={handleRefresh}
          disabled={refreshing}
          aria-label="Refresh meal suggestions"
          className="grid size-7 shrink-0 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-50"
        >
          <RotateCcw className={cn("size-3.5", refreshing && "animate-spin")} />
        </button>
      </div>

      {data.suggestions.length === 0 ? (
        <p className="mt-4 text-sm text-muted-foreground">
          Nothing in your library fits what's left. Try the AI lookup.
        </p>
      ) : (
        <div className="mt-4 flex flex-col divide-y divide-border">
          {data.suggestions.map(({ meal, reason }) => (
            <div key={meal.id} className="flex items-start justify-between gap-3 py-3 first:pt-0">
              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <span className="truncate text-[0.95rem] font-medium text-foreground">
                    {meal.name}
                  </span>
                  {meal.servingSize && (
                    <span className="shrink-0 font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
                      {meal.servingSize}
                    </span>
                  )}
                </div>
                <div className="mt-1 flex items-center gap-3">
                  <span className="font-mono text-xs text-muted-foreground">
                    {meal.calories} kcal
                  </span>
                  <MacroTrio protein={meal.protein} carbs={meal.carbs} fat={meal.fat} />
                </div>
                <p className="mt-1 text-xs italic text-muted-foreground">{reason}</p>
              </div>
              <div className="shrink-0" onClick={(e) => e.stopPropagation()}>
                <AddToLogButton meal={meal} className="sm:text-xs" onLogged={onLogged} />
              </div>
            </div>
          ))}
        </div>
      )}
    </motion.div>
  )
}
