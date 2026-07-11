import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { toast } from "sonner"
import { Plus, Camera, Barcode, RotateCcw, Flame, Drumstick } from "lucide-react"
import { useMode } from "@/components/site/mode-context"
import { editorialAccent } from "@/app-editorial/theme"
import { AddMealDialog } from "@/app/nutrition/add-meal-dialog"
import { TodayOverview, GOALS } from "@/app-editorial/macro-summary"
import { StatCard } from "@/app-editorial/stat-card"
import { WeekChart } from "@/app-editorial/week-chart"
import { LogToolbar, LogAction } from "@/app-editorial/quick-actions"
import { MealRow } from "@/app-editorial/meal-row"
import { useMeals } from "@/app-editorial/use-meals"

function comingSoon(feature: string) {
  toast(`${feature} is coming soon.`)
}

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

export function NutritionHome() {
  const { mode } = useMode()
  const accent = editorialAccent[mode]
  const { meals, loading, addMeal, removeMeal } = useMeals()

  const totals = React.useMemo(
    () =>
      meals.reduce(
        (acc, m) => ({
          calories: acc.calories + m.calories,
          protein: acc.protein + m.protein,
          carbs: acc.carbs + m.carbs,
          fat: acc.fat + m.fat,
        }),
        { calories: 0, protein: 0, carbs: 0, fat: 0 }
      ),
    [meals]
  )

  const proteinLeft = Math.max(GOALS.protein - totals.protein, 0)
  const today = new Date().toLocaleDateString(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  })

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      {/* Masthead */}
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            {today}
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            Nutrition
          </h1>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-border bg-card px-3.5 py-1.5">
          <Flame className="size-4 text-[var(--accent-ink)]" />
          <span className="font-mono text-sm font-medium text-foreground">6</span>
          <span className="text-sm text-muted-foreground">day streak</span>
        </div>
      </motion.header>

      {/* Overview + KPIs */}
      <motion.section {...fade(0.05)} className="grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <TodayOverview accent={accent} {...totals} />
        </div>
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-1">
          <StatCard
            icon={Flame}
            label="Streak"
            value={6}
            unit="days"
            hint="Log today to keep it"
          />
          <StatCard
            icon={Drumstick}
            label="Protein left"
            value={proteinLeft}
            unit="g"
            hint={`of ${GOALS.protein}g target`}
          />
        </div>
      </motion.section>

      {/* Weekly */}
      <motion.section {...fade(0.1)}>
        <WeekChart accent={accent} calories={totals.calories} goal={GOALS.calories} />
      </motion.section>

      {/* Log + meals */}
      <motion.section {...fade(0.15)} className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
            Today's meals
            <span className="ml-2 font-mono text-sm font-normal text-muted-foreground">
              {meals.length}
            </span>
          </h2>
          <LogToolbar>
            <AddMealDialog
              onAdd={addMeal}
              trigger={<LogAction icon={Plus} label="Add meal" primary />}
            />
            <LogAction
              icon={Camera}
              label="Photo"
              onClick={() => comingSoon("Photo log")}
            />
            <LogAction
              icon={Barcode}
              label="Scan"
              onClick={() => comingSoon("Barcode scan")}
            />
            <LogAction
              icon={RotateCcw}
              label="Repeat"
              onClick={() => comingSoon("Repeat yesterday")}
            />
          </LogToolbar>
        </div>

        <div className="rounded-xl border border-border bg-card px-6">
          {loading ? (
            <div className="flex flex-col gap-3 py-6">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className="h-10 animate-pulse rounded-lg bg-muted"
                  style={{ opacity: 1 - i * 0.25 }}
                />
              ))}
            </div>
          ) : meals.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-14 text-center">
              <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
                <Plus className="size-5" />
              </span>
              <div>
                <div className="font-medium text-foreground">No meals logged yet</div>
                <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                  Add your first meal to fill in today's ring and macro targets.
                </p>
              </div>
              <AddMealDialog
                onAdd={addMeal}
                trigger={
                  <button
                    type="button"
                    className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
                  >
                    <Plus className="size-4" /> Add your first meal
                  </button>
                }
              />
            </div>
          ) : (
            <>
              <div className="grid grid-cols-[1.4fr_1fr_auto_auto] gap-4 border-b border-border py-2.5 font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground max-sm:grid-cols-[1fr_auto]">
                <span>Meal</span>
                <span className="hidden sm:block">Macros</span>
                <span className="text-right">kcal</span>
                <span className="w-7" />
              </div>
              <AnimatePresence initial={false}>
                {meals.map((meal) => (
                  <MealRow
                    key={meal.id}
                    meal={meal}
                    onDelete={() => removeMeal(meal.id)}
                  />
                ))}
              </AnimatePresence>
            </>
          )}
        </div>
      </motion.section>
    </div>
  )
}
