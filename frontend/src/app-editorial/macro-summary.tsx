import { DEFAULT_TARGETS, type Targets } from "@/lib/nutrition"
import type { Pace } from "@/app-editorial/pace"

// Kept for existing imports — now re-points to the shared default targets.
export const GOALS = DEFAULT_TARGETS

const macroMeta = [
  { key: "protein", label: "Protein", color: "#ff6b35" },
  { key: "carbs", label: "Carbs", color: "#d9a441" },
  { key: "fat", label: "Fat", color: "#8a9b3b" },
] as const

export function TodayOverview({
  accent,
  calories,
  protein,
  carbs,
  fat,
  goals = DEFAULT_TARGETS,
  pace,
}: {
  accent: string
  calories: number
  protein: number
  carbs: number
  fat: number
  goals?: Targets
  pace?: Pace
}) {
  const values = { protein, carbs, fat }
  const pct = Math.min((calories / goals.calories) * 100, 100)
  const remaining = Math.max(goals.calories - calories, 0)
  const over = pace?.status === "over"

  return (
    <div className="grid gap-8 rounded-xl border border-border bg-card p-6 sm:grid-cols-[auto_1fr] sm:p-8">
      <div className="flex items-center gap-5">
        <div
          className="relative flex size-28 shrink-0 items-center justify-center rounded-full"
          style={{
            background: `conic-gradient(${accent} ${pct}%, color-mix(in oklab, ${accent} 12%, transparent) 0)`,
          }}
        >
          <div className="absolute inset-[7px] rounded-full bg-card" />
          <div className="relative text-center">
            <div className="font-mono text-2xl font-semibold leading-none text-foreground">
              {calories}
            </div>
            <div className="mt-1 font-mono text-[0.6rem] uppercase tracking-widest text-muted-foreground">
              kcal
            </div>
          </div>
        </div>
        <div>
          <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
            Consumed
          </div>
          <div className="mt-1 text-sm text-foreground">
            of {goals.calories.toLocaleString()} kcal
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-1.5">
            <span
              className={`inline-flex items-center rounded-md px-2 py-0.5 font-mono text-xs font-medium ${
                over
                  ? "bg-[color-mix(in_oklab,#c85a3c_16%,transparent)] text-[#c85a3c]"
                  : "bg-[var(--accent-tint)] text-[var(--accent-ink)]"
              }`}
            >
              {over
                ? `${Math.abs(pace!.remaining).toLocaleString()} over`
                : `${remaining.toLocaleString()} left`}
            </span>
            {pace && (
              <span className="text-xs text-muted-foreground">{pace.label}</span>
            )}
          </div>
        </div>
      </div>

      <div className="flex flex-col justify-center gap-4 sm:border-l sm:border-border sm:pl-8">
        {macroMeta.map((m) => {
          const val = values[m.key]
          const goal = goals[m.key]
          const p = Math.min((val / goal) * 100, 100)
          return (
            <div key={m.key}>
              <div className="flex items-baseline justify-between">
                <span className="font-mono text-[0.65rem] uppercase tracking-[0.14em] text-muted-foreground">
                  {m.label}
                </span>
                <span className="font-mono text-xs text-foreground">
                  {val}
                  <span className="text-muted-foreground">/{goal}g</span>
                </span>
              </div>
              <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-muted">
                <div
                  className="h-full rounded-full transition-[width] duration-500"
                  style={{ width: `${p}%`, backgroundColor: m.color }}
                />
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
