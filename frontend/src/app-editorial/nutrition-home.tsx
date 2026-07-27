import * as React from "react"
import { Link } from "react-router-dom"
import { AnimatePresence, motion } from "framer-motion"
import { toast } from "sonner"
import { Plus, Camera, Barcode, RotateCcw, Flame, Drumstick, Sparkles } from "lucide-react"
import { useMode } from "@/components/site/mode-context"
import { editorialAccent } from "@/app-editorial/theme"
import { AddMealDialog } from "@/app/nutrition/add-meal-dialog"
import { AiEstimateDialog } from "@/app-editorial/ai-estimate-dialog"
import { TodayOverview } from "@/app-editorial/macro-summary"
import { StatCard } from "@/app-editorial/stat-card"
import { WeekChart } from "@/app-editorial/week-chart"
import { AiCoachCard } from "@/app-editorial/ai/ai-coach-card"
import { MealSuggestionsCard } from "@/app-editorial/ai/meal-suggestions-card"
import { AiMealLookupDialog } from "@/app-editorial/ai/ai-meal-lookup-dialog"
import { PhotoLogDialog } from "@/app-editorial/photo-log-dialog"
import { BarcodeScanDialog } from "@/app-editorial/barcode-scan-dialog"
import { LogToolbar, LogAction } from "@/app-editorial/quick-actions"
import { MealRow } from "@/app-editorial/meal-row"
import { useMeals } from "@/app-editorial/use-meals"
import { useWeekMeals } from "@/app-editorial/use-week-meals"
import { useStreaks } from "@/app-editorial/use-streaks"
import { useMe, useTargets } from "@/app-editorial/use-me"
import { computeDirection } from "@/lib/nutrition"
import { computePace } from "@/app-editorial/pace"
import { useI18n } from "@/lib/i18n"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

export function NutritionHome() {
  const { mode } = useMode()
  const accent = editorialAccent[mode]
  const { t, formatNumber, formatDate } = useI18n()
  const comingSoon = (feature: string) => toast(t("common.comingSoon", { feature }))
  const { meals, loading, addMeal, deleteMeal, dropMeal, reload } = useMeals()
  const { days: weekDays, loading: weekLoading } = useWeekMeals()
  const targets = useTargets()
  const { profile } = useMe()
  const { logging: loggingStreak, goal: goalStreak } = useStreaks(targets.calories)
  const direction = profile
    ? computeDirection({ weightKg: profile.weightKg, goalWeightKg: profile.goalWeightKg })
    : "maintain"

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

  const pace = computePace(totals.calories, targets.calories)
  const proteinLeft = Math.max(targets.protein - totals.protein, 0)
  const remaining = {
    calories: Math.max(targets.calories - totals.calories, 0),
    protein: Math.max(targets.protein - totals.protein, 0),
    carbs: Math.max(targets.carbs - totals.carbs, 0),
    fat: Math.max(targets.fat - totals.fat, 0),
  }
  const today = formatDate(new Date(), {
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
            {t("nutrition.title")}
          </h1>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-border bg-card px-3.5 py-1.5">
          <Flame className="size-4 text-[var(--accent-ink)]" />
          <span className="font-mono text-sm font-medium text-foreground">{formatNumber(loggingStreak)}</span>
          <span className="text-sm text-muted-foreground">{t("common.dayStreak")}</span>
        </div>
      </motion.header>

      {/* Overview + KPIs */}
      <motion.section {...fade(0.05)} className="grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <TodayOverview accent={accent} {...totals} goals={targets} pace={pace} />
        </div>
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-1">
          <StatCard
            icon={Flame}
            label={t("nutrition.onTargetStreak")}
            value={formatNumber(goalStreak)}
            unit={goalStreak === 1 ? t("nutrition.day") : t("nutrition.days")}
            hint={
              goalStreak > 0
                ? t("nutrition.daysWithinGoal")
                : t("nutrition.hitGoalToStart")
            }
          />
          <StatCard
            icon={Drumstick}
            label={t("nutrition.proteinLeft")}
            value={formatNumber(proteinLeft)}
            unit={t("common.g")}
            hint={t("nutrition.ofTarget", { value: formatNumber(targets.protein) })}
          />
        </div>
      </motion.section>

      {/* Weekly */}
      <motion.section {...fade(0.1)}>
        <WeekChart
          accent={accent}
          days={weekDays}
          goal={targets.calories}
          direction={direction}
          loading={weekLoading}
        />
      </motion.section>

      {/* AI coach */}
      <motion.section {...fade(0.12)}>
        <AiCoachCard />
      </motion.section>

      {/* Up next — meal suggestions from remaining macros */}
      <motion.section {...fade(0.13)}>
        <MealSuggestionsCard remaining={remaining} ready={!loading} onLogged={reload} />
      </motion.section>

      {/* Log + meals */}
      <motion.section {...fade(0.15)} className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-baseline gap-3">
            <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
              {t("nutrition.todaysMeals")}
              <span className="ms-2 font-mono text-sm font-normal text-muted-foreground">
                {formatNumber(meals.length)}
              </span>
            </h2>
            <Link
              to="/dashboard/nutrition/today"
              className="text-sm text-[var(--accent-ink)] hover:underline underline-offset-4"
            >
              {t("nutrition.openTodaysLog")}
            </Link>
          </div>
          <LogToolbar>
            <AiEstimateDialog
              onAdd={addMeal}
              trigger={<LogAction icon={Sparkles} label={t("today.aiEstimate")} primary />}
            />
            <AddMealDialog
              onAdd={addMeal}
              trigger={<LogAction icon={Plus} label={t("today.addMeal")} />}
            />
            <AiMealLookupDialog
              trigger={<LogAction icon={Sparkles} label={t("today.aiLookup")} />}
            />
            <PhotoLogDialog
              onAdd={addMeal}
              trigger={<LogAction icon={Camera} label={t("today.photo")} />}
            />
            <BarcodeScanDialog
              onAdd={addMeal}
              trigger={<LogAction icon={Barcode} label={t("today.scan")} />}
            />
            <LogAction
              icon={RotateCcw}
              label={t("today.repeat")}
              onClick={() => comingSoon(t("feature.repeatYesterday"))}
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
                <div className="font-medium text-foreground">{t("nutrition.noMealsYet")}</div>
                <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                  {t("nutrition.noMealsHint")}
                </p>
              </div>
              <div className="mt-1 flex flex-wrap items-center justify-center gap-2">
                <AiEstimateDialog
                  onAdd={addMeal}
                  trigger={
                    <button
                      type="button"
                      className="inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
                    >
                      <Sparkles className="size-4" /> {t("nutrition.estimateWithAi")}
                    </button>
                  }
                />
                <AddMealDialog
                  onAdd={addMeal}
                  trigger={
                    <button
                      type="button"
                      className="inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted"
                    >
                      <Plus className="size-4" /> {t("nutrition.addMealManually")}
                    </button>
                  }
                />
              </div>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-[1.4fr_1fr_auto_auto] gap-4 border-b border-border py-2.5 font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground max-sm:grid-cols-[1fr_auto]">
                <span>{t("nutrition.colMeal")}</span>
                <span className="hidden sm:block">{t("nutrition.colMacros")}</span>
                <span className="text-end">{t("nutrition.colKcal")}</span>
                <span className="w-7" />
              </div>
              <AnimatePresence initial={false}>
                {meals.map((meal) => (
                  <MealRow
                    key={meal.id}
                    meal={meal}
                    onDelete={() => deleteMeal(meal.id)}
                    onRemoved={() => dropMeal(meal.id)}
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
