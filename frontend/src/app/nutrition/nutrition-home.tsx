import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { toast } from "sonner"
import { Plus, Camera, Barcode, RotateCcw } from "lucide-react"
import {
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  EmptyDescription,
  EmptyContent,
} from "@/components/ui/empty"
import { Button } from "@/components/ui/button"
import { useMode, modeColors } from "@/components/site/mode-context"
import { QuickActionsRow, QuickActionButton } from "@/app/quick-actions"
import { AddMealDialog } from "@/app/nutrition/add-meal-dialog"
import { MealRow } from "@/app/nutrition/meal-row"
import { MacroSummary } from "@/app/nutrition/macro-summary"
import type { Meal } from "@/app/nutrition/types"

function comingSoon(feature: string) {
  toast(`${feature} is coming soon.`)
}

export function NutritionHome() {
  const { mode } = useMode()
  const accent = modeColors[mode]
  const [meals, setMeals] = React.useState<Meal[]>([])

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

  function addMeal(meal: Meal) {
    setMeals((prev) => [meal, ...prev])
  }

  function removeMeal(id: string) {
    setMeals((prev) => prev.filter((m) => m.id !== id))
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-8">
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <h1 className="font-heading text-3xl font-semibold tracking-tight text-bone">
          Nutrition
        </h1>
        <p className="mt-1 text-smoke">
          Today, {new Date().toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" })}
        </p>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.05 }}
      >
        <MacroSummary accent={accent} {...totals} />
      </motion.div>

      <div>
        <h2 className="mb-3 text-sm font-medium text-smoke">Quick actions</h2>
        <QuickActionsRow>
          <AddMealDialog
            onAdd={addMeal}
            trigger={
              <QuickActionButton
                icon={Plus}
                label="Add meal"
                accent={accent}
                delay={0}
              />
            }
          />
          <QuickActionButton
            icon={Camera}
            label="Photo log"
            accent={accent}
            delay={0.05}
            onClick={() => comingSoon("Photo log")}
          />
          <QuickActionButton
            icon={Barcode}
            label="Scan barcode"
            accent={accent}
            delay={0.1}
            onClick={() => comingSoon("Barcode scan")}
          />
          <QuickActionButton
            icon={RotateCcw}
            label="Repeat yesterday"
            accent={accent}
            delay={0.15}
            onClick={() => comingSoon("Repeat yesterday")}
          />
        </QuickActionsRow>
      </div>

      <div>
        <h2 className="mb-3 text-sm font-medium text-smoke">Today's meals</h2>

        {meals.length === 0 ? (
          <Empty className="rounded-3xl border border-bone/10 bg-char-2">
            <EmptyHeader>
              <EmptyMedia
                variant="icon"
                style={{ backgroundColor: `${accent}1f`, color: accent }}
              >
                <Plus className="size-5" />
              </EmptyMedia>
              <EmptyTitle>No meals logged yet</EmptyTitle>
              <EmptyDescription>
                Add your first meal to start filling in today's rings.
              </EmptyDescription>
            </EmptyHeader>
            <EmptyContent>
              <AddMealDialog
                onAdd={addMeal}
                trigger={<Button>Add your first meal</Button>}
              />
            </EmptyContent>
          </Empty>
        ) : (
          <div className="flex flex-col gap-2">
            <AnimatePresence initial={false}>
              {meals.map((meal) => (
                <MealRow
                  key={meal.id}
                  meal={meal}
                  accent={accent}
                  onDelete={() => removeMeal(meal.id)}
                />
              ))}
            </AnimatePresence>
          </div>
        )}
      </div>
    </div>
  )
}
