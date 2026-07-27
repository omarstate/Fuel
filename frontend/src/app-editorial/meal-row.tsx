import { motion } from "framer-motion"
import { Trash2 } from "lucide-react"
import { type Meal } from "@/app/nutrition/types"
import { MorphButton } from "@/components/ui/morph-button"
import { useI18n } from "@/lib/i18n"

export function MealRow({
  meal,
  onDelete,
  onRemoved,
}: {
  meal: Meal
  /** DB delete — returns whether it succeeded so the morph can show success/error. */
  onDelete: () => Promise<boolean>
  /** Drops the meal from local state, called after the success beat. */
  onRemoved: () => void
}) {
  const { t, formatNumber } = useI18n()
  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: -6 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, height: 0, marginTop: 0 }}
      transition={{ duration: 0.22 }}
      className="group grid grid-cols-[1fr_auto_auto] items-center gap-3 border-b border-border py-3.5 last:border-b-0 sm:grid-cols-[1.4fr_1fr_auto_auto] sm:gap-4"
    >
      {/* name + type */}
      <div className="min-w-0">
        <div className="truncate text-[0.95rem] font-medium text-foreground">
          {meal.name}
        </div>
        <div className="mt-0.5 font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
          {t(`mealType.${meal.mealType}`)}
          {meal.servingSize ? ` · ${meal.servingSize}` : ""}
        </div>
      </div>

      {/* macros */}
      <div className="hidden items-center gap-4 font-mono text-xs text-muted-foreground sm:flex">
        <span>
          <span className="text-[#b5431c]">P</span> {formatNumber(meal.protein)}
        </span>
        <span>
          <span className="text-[#a9781f]">C</span> {formatNumber(meal.carbs)}
        </span>
        <span>
          <span className="text-[#5c6d0a]">F</span> {formatNumber(meal.fat)}
        </span>
      </div>

      {/* kcal */}
      <div className="text-end font-mono text-sm font-semibold text-foreground">
        {formatNumber(meal.calories)}
        <span className="ms-1 text-[0.65rem] font-normal text-muted-foreground">
          {t("common.kcal")}
        </span>
      </div>

      {/* delete */}
      <MorphButton
        variant="inline"
        intent="destructive"
        idleIcon={Trash2}
        idleLabel={t("common.remove") + " " + meal.name}
        successLabel={t("common.deleted")}
        onAction={onDelete}
        onSuccess={onRemoved}
        className="opacity-100 sm:ms-2 sm:opacity-0 sm:group-hover:opacity-100"
      />
    </motion.div>
  )
}
