import { Link } from "react-router-dom"
import { AnimatePresence, motion } from "framer-motion"
import { CalendarClock, RotateCcw, UtensilsCrossed } from "lucide-react"
import { useMealHistory, type MealHistoryDay } from "@/app-editorial/use-meal-history"
import { MealRow } from "@/app-editorial/meal-row"
import { dayKey } from "@/app-editorial/day-bounds"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function formatDayLabel(date: Date) {
  const today = new Date()
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)

  if (dayKey(date) === dayKey(today)) return "Today"
  if (dayKey(date) === dayKey(yesterday)) return "Yesterday"

  return date.toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  })
}

function DayGroup({
  day,
  delay,
  onDelete,
  onRemoved,
}: {
  day: MealHistoryDay
  delay: number
  onDelete: (id: string) => Promise<boolean>
  onRemoved: (id: string) => void
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay }}
      className="rounded-xl border border-border bg-card px-6"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border py-4">
        <div>
          <div className="font-heading text-base font-semibold tracking-tight text-foreground">
            {formatDayLabel(day.date)}
          </div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
            {day.meals.length} {day.meals.length === 1 ? "meal" : "meals"}
          </div>
        </div>
        <div className="flex items-center gap-4 font-mono text-xs text-muted-foreground">
          <span>
            <span className="text-[#b5431c]">P</span> {day.totals.protein}
          </span>
          <span>
            <span className="text-[#a9781f]">C</span> {day.totals.carbs}
          </span>
          <span>
            <span className="text-[#57783a]">F</span> {day.totals.fat}
          </span>
          <span className="text-sm font-semibold text-foreground">
            {day.totals.calories}
            <span className="ml-1 text-[0.65rem] font-normal text-muted-foreground">kcal</span>
          </span>
        </div>
      </div>

      <AnimatePresence initial={false}>
        {day.meals.map((meal) => (
          <MealRow
            key={meal.id}
            meal={meal}
            onDelete={() => onDelete(meal.id)}
            onRemoved={() => onRemoved(meal.id)}
          />
        ))}
      </AnimatePresence>
    </motion.div>
  )
}

/** Last 30 days of logged meals, grouped by day, most recent first. Lives
 * inside the editorial shell at /dashboard/nutrition/history. */
export function MealHistory() {
  const { days, loading, error, reload, deleteMeal, dropMeal } = useMealHistory()

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Nutrition · History
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            Meal history
          </h1>
          <p className="mt-1.5 max-w-md text-sm text-muted-foreground">
            Everything you've logged in the last 30 days, grouped by day.
          </p>
        </div>
      </motion.header>

      <motion.section {...fade(0.05)} className="flex flex-col gap-4">
        {error ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <CalendarClock className="size-5" />
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
          <div className="flex flex-col gap-4">
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                className="h-32 animate-pulse rounded-xl border border-border bg-muted"
                style={{ opacity: 1 - i * 0.2 }}
              />
            ))}
          </div>
        ) : days.length === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <UtensilsCrossed className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">No meals in the last 30 days</div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Log a meal from the Nutrition overview and it'll show up here.
              </p>
            </div>
            <Link
              to="/dashboard/nutrition"
              className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              Go to Nutrition
            </Link>
          </div>
        ) : (
          days.map((day, i) => (
            <DayGroup
              key={day.key}
              day={day}
              delay={Math.min(i, 8) * 0.03}
              onDelete={deleteMeal}
              onRemoved={dropMeal}
            />
          ))
        )}
      </motion.section>
    </div>
  )
}

export default MealHistory
