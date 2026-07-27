import * as React from "react"
import { Flame, Drumstick, Check, RotateCcw, Trophy } from "lucide-react"
import { cn } from "@/lib/utils"
import { editorialAccent, editorialAccentInk } from "@/app-editorial/theme"
import type { Mode } from "@/components/site/mode-context"
import type { Meal } from "@/app/nutrition/types"
import type { WeekDay } from "@/app-editorial/use-week-meals"
import type { Targets } from "@/lib/nutrition"
import { TodayOverview } from "@/app-editorial/macro-summary"
import { StatCard } from "@/app-editorial/stat-card"
import { WeekChart } from "@/app-editorial/week-chart"
import { MealRow } from "@/app-editorial/meal-row"
import { SetLogger } from "@/app-editorial/workouts/session/set-logger"

/**
 * Landing-page "screenshots": the real editorial app components, rendered with
 * curated sample data inside a browser-window frame. `.theme-fuel-light` is
 * scoped onto the screen surface so the app tokens (card/border/foreground…)
 * resolve even though the surrounding landing page uses its own palette.
 */

const noop = () => {}
const noopAsync = async () => true

/** Chrome + themed surface. `mode` picks the nutrition (green) or workouts
 *  (orange) accent, matching how the real app themes each route. */
export function ScreenFrame({
  url,
  mode,
  className,
  children,
}: {
  url: string
  mode: Mode
  className?: string
  children: React.ReactNode
}) {
  const accent = editorialAccent[mode]
  const accentInk = editorialAccentInk[mode]
  return (
    <div
      className={cn(
        "flex flex-col overflow-hidden rounded-2xl border border-[rgba(20,18,15,0.1)] bg-[#fffdf7]",
        "shadow-[0_34px_70px_-30px_rgba(20,18,15,0.42),0_10px_24px_-14px_rgba(20,18,15,0.2)]",
        className
      )}
    >
      {/* window chrome */}
      <div className="flex items-center gap-2 border-b border-[rgba(20,18,15,0.08)] bg-[#f1ebdd] px-4 py-3">
        <div className="flex gap-1.5">
          <span className="size-2.5 rounded-full bg-[rgba(20,18,15,0.16)]" />
          <span className="size-2.5 rounded-full bg-[rgba(20,18,15,0.16)]" />
          <span className="size-2.5 rounded-full bg-[rgba(20,18,15,0.16)]" />
        </div>
        <div className="mx-auto flex items-center gap-1.5 rounded-md bg-[#fffdf7] px-3 py-1 font-mono text-[0.7rem] text-[#6f6a5c] ring-1 ring-[rgba(20,18,15,0.06)]">
          <span className="size-1.5 rounded-full" style={{ backgroundColor: accent }} />
          {url}
        </div>
        <div className="w-11" aria-hidden />
      </div>

      {/* themed app surface */}
      <div
        className="theme-fuel-light min-h-0 flex-1 overflow-hidden bg-background"
        style={
          {
            "--accent-ink": accentInk,
            "--accent-tint": `${accent}24`,
            "--primary": accent,
            "--ring": accent,
          } as React.CSSProperties
        }
      >
        <div className="h-full p-5 sm:p-6">{children}</div>
      </div>
    </div>
  )
}

/* ------------------------------- Nutrition ------------------------------- */

const NUTRITION_GOALS: Targets = { calories: 2200, protein: 165, carbs: 220, fat: 70 }

const NUTRITION_TOTALS = { calories: 1640, protein: 118, carbs: 172, fat: 46 }

const now = new Date()
const SAMPLE_MEALS: Meal[] = [
  {
    id: "m1",
    name: "Greek yogurt & berries",
    mealType: "breakfast",
    servingSize: "1 bowl",
    calories: 320,
    protein: 24,
    carbs: 38,
    fat: 8,
    loggedAt: now,
  },
  {
    id: "m2",
    name: "Grilled chicken & rice",
    mealType: "lunch",
    calories: 610,
    protein: 52,
    carbs: 68,
    fat: 14,
    loggedAt: now,
  },
  {
    id: "m3",
    name: "Whey protein shake",
    mealType: "snack",
    servingSize: "1 scoop",
    calories: 180,
    protein: 30,
    carbs: 9,
    fat: 3,
    loggedAt: now,
  },
]

const WEEK_DAYS: WeekDay[] = [
  { key: "d0", index: 0, calories: 2150, logged: true, isToday: false, isFuture: false },
  { key: "d1", index: 1, calories: 2320, logged: true, isToday: false, isFuture: false },
  { key: "d2", index: 2, calories: 2080, logged: true, isToday: false, isFuture: false },
  { key: "d3", index: 3, calories: 2240, logged: true, isToday: false, isFuture: false },
  { key: "d4", index: 4, calories: 1980, logged: true, isToday: false, isFuture: false },
  { key: "d5", index: 5, calories: 1640, logged: true, isToday: true, isFuture: false },
  { key: "d6", index: 6, calories: 0, logged: false, isToday: false, isFuture: true },
]

export function NutritionPreview() {
  const accent = editorialAccent.nutrition
  return (
    <div className="flex h-full flex-col gap-4">
      <TodayOverview accent={accent} {...NUTRITION_TOTALS} goals={NUTRITION_GOALS} />
      <div className="grid grid-cols-2 gap-4">
        <StatCard icon={Flame} label="On-target streak" value={6} unit="days" hint="Days within goal" />
        <StatCard icon={Drumstick} label="Protein left" value={47} unit="g" hint="of 165 target" />
      </div>
      <div className="rounded-xl border border-border bg-card px-6">
        <div className="grid grid-cols-[1.4fr_1fr_auto_auto] gap-4 border-b border-border py-2.5 font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground">
          <span>Meal</span>
          <span>Macros</span>
          <span className="text-end">Kcal</span>
          <span className="w-7" />
        </div>
        {SAMPLE_MEALS.map((meal) => (
          <MealRow key={meal.id} meal={meal} onDelete={noopAsync} onRemoved={noop} />
        ))}
      </div>
    </div>
  )
}

/* -------------------------------- Workouts ------------------------------- */

const SAMPLE_SETS = [
  { n: 1, weight: "80.0", reps: 5, pr: false },
  { n: 2, weight: "82.5", reps: 5, pr: true },
  { n: 3, weight: "82.5", reps: 5, pr: false },
]

export function WorkoutPreview() {
  return (
    <div className="flex h-full flex-col gap-4">
      {/* exercise header */}
      <div className="flex items-end justify-between border-b border-border pb-4">
        <div>
          <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--accent-ink)]">
            Push day · working set 3 of 4
          </div>
          <h3 className="mt-1.5 font-heading text-2xl font-semibold tracking-tight text-foreground">
            Bench Press
          </h3>
        </div>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-[var(--accent-tint)] px-3 py-1 font-mono text-xs font-medium text-[var(--accent-ink)]">
          <Trophy className="size-3.5" /> New PR
        </span>
      </div>

      {/* logged sets */}
      <div className="rounded-xl border border-border bg-card">
        {SAMPLE_SETS.map((s) => (
          <div
            key={s.n}
            className="flex items-center justify-between border-b border-border px-5 py-3 last:border-b-0"
          >
            <div className="flex items-center gap-3">
              <span className="grid size-7 place-items-center rounded-md bg-muted font-mono text-xs font-semibold text-foreground">
                {s.n}
              </span>
              <span className="font-mono text-sm text-foreground">
                {s.weight} kg <span className="text-muted-foreground">×</span> {s.reps}
              </span>
            </div>
            {s.pr ? (
              <span className="inline-flex items-center gap-1 font-mono text-[0.7rem] font-medium text-[var(--accent-ink)]">
                <Trophy className="size-3.5" /> best
              </span>
            ) : (
              <Check className="size-4 text-muted-foreground" />
            )}
          </div>
        ))}
      </div>

      {/* live one-tap logger (real component) */}
      <div className="rounded-xl border border-border bg-card p-5">
        <div className="mb-3 font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
          Next set
        </div>
        <SetLogger defaultWeight={82.5} defaultReps={5} onLog={noopAsync} />
      </div>
    </div>
  )
}

/* --------------------------------- Coach --------------------------------- */

const INSIGHTS = [
  {
    title: "Protein is your anchor",
    body: "You've cleared 90% of your protein target five days running — that's what protects muscle while you cut.",
  },
  {
    title: "Weekends drift a little",
    body: "Saturday calories run ~18% above weekdays. A lighter breakfast keeps the day on plan.",
  },
]

const TIPS = [
  "Front-load 30g of protein at breakfast to make the target easy.",
  "You have 560 kcal left today — a balanced dinner fits comfortably.",
]

export function CoachPreview() {
  return (
    <div className="flex h-full flex-col gap-4">
      <div className="rounded-xl border border-border bg-card p-6">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
                Coach
              </div>
              <span className="inline-flex items-center gap-1 rounded-full border border-border bg-background px-2 py-0.5 font-mono text-[0.65rem] text-foreground">
                <Flame className="size-3 text-[var(--accent-ink)]" /> 6 day streak
              </span>
            </div>
            <h3 className="mt-2 font-heading text-lg font-semibold tracking-tight text-foreground">
              Strong week — you're trending right toward your cut.
            </h3>
          </div>
          <span className="grid size-7 shrink-0 place-items-center rounded-md text-muted-foreground">
            <RotateCcw className="size-3.5" />
          </span>
        </div>

        <div className="mt-4 flex flex-col gap-3">
          {INSIGHTS.map((insight) => (
            <div key={insight.title}>
              <div className="text-sm font-semibold text-foreground">{insight.title}</div>
              <p className="mt-0.5 text-sm text-muted-foreground">{insight.body}</p>
            </div>
          ))}
        </div>

        <ul className="mt-5 flex flex-col gap-2 border-t border-border pt-4">
          {TIPS.map((tip) => (
            <li key={tip} className="flex items-start gap-2 text-sm text-foreground">
              <Check className="mt-0.5 size-4 shrink-0 text-[var(--accent-ink)]" />
              <span>{tip}</span>
            </li>
          ))}
        </ul>
      </div>

      <WeekChart
        accent={editorialAccent.nutrition}
        days={WEEK_DAYS}
        goal={NUTRITION_GOALS.calories}
        direction="cut"
      />
    </div>
  )
}
