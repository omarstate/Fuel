import { motion } from "framer-motion"
import { Trash2 } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { mealTypeLabel, type Meal } from "@/app/nutrition/types"

export function MealRow({
  meal,
  accent,
  onDelete,
}: {
  meal: Meal
  accent: string
  onDelete: () => void
}) {
  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, x: -12 }}
      transition={{ duration: 0.25 }}
      className="group flex items-center justify-between gap-4 rounded-2xl border border-bone/10 bg-char-2 px-4 py-3"
    >
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm font-medium text-bone">
            {meal.name}
          </span>
          <Badge
            variant="secondary"
            className="border-0 text-[0.65rem]"
            style={{ backgroundColor: `${accent}1f`, color: accent }}
          >
            {mealTypeLabel[meal.mealType]}
          </Badge>
        </div>
        <div className="mt-0.5 font-mono text-xs text-smoke">
          {meal.calories} kcal · P{meal.protein} C{meal.carbs} F{meal.fat}
          {meal.servingSize ? ` · ${meal.servingSize}` : ""}
        </div>
      </div>

      <Button
        variant="ghost"
        size="icon-sm"
        onClick={onDelete}
        aria-label={`Remove ${meal.name}`}
        className="shrink-0 text-smoke opacity-0 transition-opacity group-hover:opacity-100 hover:text-destructive"
      >
        <Trash2 />
      </Button>
    </motion.div>
  )
}
