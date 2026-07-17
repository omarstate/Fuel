import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { toast } from "sonner"
import { Plus, Camera, Barcode, RotateCcw, Sparkles, BookOpen } from "lucide-react"
import { useMode } from "@/components/site/mode-context"
import { editorialAccent } from "@/app-editorial/theme"
import { AddMealDialog } from "@/app/nutrition/add-meal-dialog"
import { LibraryPickerDialog } from "@/app-editorial/library-picker-dialog"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { TodayOverview } from "@/app-editorial/macro-summary"
import { AiMealLookupDialog } from "@/app-editorial/ai/ai-meal-lookup-dialog"
import { LogToolbar, LogAction } from "@/app-editorial/quick-actions"
import { MealRow } from "@/app-editorial/meal-row"
import { useMeals } from "@/app-editorial/use-meals"
import { useTargets } from "@/app-editorial/use-me"
import {
  MEAL_TYPE_ORDER,
  mealTypeLabel,
  type Meal,
  type MealType,
} from "@/app/nutrition/types"

function comingSoon(feature: string) {
  toast(`${feature} is coming soon.`)
}

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function sectionSubtotal(meals: Meal[]): string {
  const parts: string[] = [`${meals.length} item${meals.length === 1 ? "" : "s"}`]
  const kcal = meals.reduce((acc, m) => acc + m.calories, 0)
  const protein = meals.reduce((acc, m) => acc + m.protein, 0)
  if (kcal > 0) parts.push(`${kcal} kcal`)
  if (protein > 0) parts.push(`${protein} g protein`)
  return parts.join(" · ")
}

function MealSection({
  type,
  meals,
  onAddMeal,
  onDelete,
  onRemoved,
  onLogged,
}: {
  type: MealType
  meals: Meal[]
  onAddMeal: (meal: Meal) => Promise<boolean>
  onDelete: (id: string) => Promise<boolean>
  onRemoved: (id: string) => void
  onLogged: () => void
}) {
  const label = mealTypeLabel[type]
  const [customOpen, setCustomOpen] = React.useState(false)
  const [pickerOpen, setPickerOpen] = React.useState(false)

  return (
    <div className="rounded-xl border border-border bg-card px-6">
      <div className="flex items-center justify-between gap-3 border-b border-border py-3.5">
        <div className="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-1">
          <h2 className="font-heading text-base font-semibold tracking-tight text-foreground">
            {label}
          </h2>
          <span className="font-mono text-xs text-muted-foreground">
            {sectionSubtotal(meals)}
          </span>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              aria-label={`Add ${label.toLowerCase()}`}
              className="grid size-7 shrink-0 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
            >
              <Plus className="size-4" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="min-w-44">
            <DropdownMenuItem onSelect={() => setCustomOpen(true)}>
              <Plus className="size-4" /> New custom meal
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setPickerOpen(true)}>
              <BookOpen className="size-4" /> From library
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        <AddMealDialog
          onAdd={onAddMeal}
          defaultMealType={type}
          open={customOpen}
          onOpenChange={setCustomOpen}
        />
        <LibraryPickerDialog
          mealType={type}
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          onLogged={onLogged}
        />
      </div>

      {meals.length === 0 ? (
        <div className="py-4 font-mono text-xs text-muted-foreground">
          Nothing logged for {label.toLowerCase()} yet.
        </div>
      ) : (
        <AnimatePresence initial={false}>
          {meals.map((meal) => (
            <MealRow
              key={meal.id}
              meal={meal}
              onDelete={() => onDelete(meal.id)}
              onRemoved={() => onRemoved(meal.id)}
            />
          ))}
        </AnimatePresence>
      )}
    </div>
  )
}

export function Today() {
  const { mode } = useMode()
  const accent = editorialAccent[mode]
  const { meals, loading, addMeal, deleteMeal, dropMeal, reload } = useMeals()
  const targets = useTargets()

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

  const byType = React.useMemo(() => {
    const groups: Record<MealType, Meal[]> = {
      breakfast: [],
      lunch: [],
      dinner: [],
      snack: [],
    }
    for (const meal of meals) groups[meal.mealType].push(meal)
    return groups
  }, [meals])

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
            Today's log
          </h1>
          <p className="mt-2 text-sm text-muted-foreground">
            Everything you've eaten today, by meal.
          </p>
        </div>
        <LogToolbar>
          <AddMealDialog
            onAdd={addMeal}
            trigger={<LogAction icon={Plus} label="Add meal" primary />}
          />
          <AiMealLookupDialog
            trigger={<LogAction icon={Sparkles} label="AI lookup" />}
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
      </motion.header>

      {/* Overview */}
      <motion.section {...fade(0.05)}>
        <TodayOverview accent={accent} {...totals} goals={targets} />
      </motion.section>

      {/* Sections */}
      {loading ? (
        <div className="flex flex-col gap-4">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="h-28 animate-pulse rounded-xl border border-border bg-muted"
              style={{ opacity: 1 - i * 0.2 }}
            />
          ))}
        </div>
      ) : (
        <motion.section {...fade(0.1)} className="flex flex-col gap-4">
          {MEAL_TYPE_ORDER.map((type) => (
            <MealSection
              key={type}
              type={type}
              meals={byType[type]}
              onAddMeal={addMeal}
              onDelete={deleteMeal}
              onRemoved={dropMeal}
              onLogged={reload}
            />
          ))}
        </motion.section>
      )}
    </div>
  )
}

export default Today
