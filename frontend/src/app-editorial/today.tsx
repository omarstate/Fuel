import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { toast } from "sonner"
import { Plus, Camera, Barcode, RotateCcw, Sparkles, BookOpen, Trash2 } from "lucide-react"
import { cn } from "@/lib/utils"
import { AddMealDialog } from "@/app/nutrition/add-meal-dialog"
import { LibraryPickerDialog } from "@/app-editorial/library-picker-dialog"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { MorphButton } from "@/components/ui/morph-button"
import { TodayRings } from "@/app-editorial/today-rings"
import { AiMealLookupDialog } from "@/app-editorial/ai/ai-meal-lookup-dialog"
import { useMeals } from "@/app-editorial/use-meals"
import { useTargets } from "@/app-editorial/use-me"
import { useI18n, type I18nContextValue } from "@/lib/i18n"
import {
  MEAL_TYPE_ORDER,
  type Meal,
  type MealType,
} from "@/app/nutrition/types"

const GREEN = "#4be08a"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

/* --- dark toolbar ------------------------------------------------------- */

type NativeButtonProps = React.ComponentProps<"button">

const DarkAction = React.forwardRef<
  HTMLButtonElement,
  NativeButtonProps & {
    icon: React.ComponentType<{ className?: string; style?: React.CSSProperties }>
    label: string
    primary?: boolean
  }
>(function DarkAction({ icon: Icon, label, primary = false, className, ...props }, ref) {
  return (
    <button
      ref={ref}
      type="button"
      className={cn(
        "inline-flex items-center gap-2 rounded-xl px-3.5 py-2.5 text-sm font-medium transition-colors sm:py-2",
        primary
          ? "bg-[#4be08a] text-[#0b0d11] hover:bg-[#3ecb7b]"
          : "bg-white/[0.06] text-white/85 hover:bg-white/[0.12]",
        className
      )}
      {...props}
    >
      <Icon
        className="size-4"
        style={primary ? undefined : { color: GREEN }}
      />
      {label}
    </button>
  )
})

/* --- dark meal row ------------------------------------------------------ */

function DarkMealRow({
  meal,
  onDelete,
  onRemoved,
}: {
  meal: Meal
  onDelete: () => Promise<boolean>
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
      className="group grid grid-cols-[1fr_auto_auto] items-center gap-3 border-b border-white/[0.06] py-3.5 last:border-b-0 sm:grid-cols-[1.4fr_1fr_auto_auto] sm:gap-4"
    >
      <div className="min-w-0">
        <div className="truncate text-[0.95rem] font-medium text-white/90">{meal.name}</div>
        <div className="mt-0.5 font-mono text-[0.7rem] uppercase tracking-[0.12em] text-white/40">
          {t(`mealType.${meal.mealType}`)}
          {meal.servingSize ? ` · ${meal.servingSize}` : ""}
        </div>
      </div>

      <div className="hidden items-center gap-4 font-mono text-xs text-white/45 sm:flex">
        <span>
          <span className="text-[#3f8dff]">P</span> {formatNumber(meal.protein)}
        </span>
        <span>
          <span className="text-[#d9a441]">C</span> {formatNumber(meal.carbs)}
        </span>
        <span>
          <span className="text-[#4be08a]">F</span> {formatNumber(meal.fat)}
        </span>
      </div>

      <div className="text-end font-mono text-sm font-semibold text-white/90">
        {formatNumber(meal.calories)}
        <span className="ms-1 text-[0.65rem] font-normal text-white/40">{t("common.kcal")}</span>
      </div>

      <MorphButton
        variant="inline"
        intent="destructive"
        idleIcon={Trash2}
        idleLabel={t("common.remove") + " " + meal.name}
        successLabel={t("common.deleted")}
        onAction={onDelete}
        onSuccess={onRemoved}
        className="text-white/40 hover:bg-white/10 hover:text-red-400 sm:ms-2 sm:opacity-0 sm:group-hover:opacity-100"
      />
    </motion.div>
  )
}

/* --- dark meal section -------------------------------------------------- */

function sectionSubtotal(meals: Meal[], i18n: I18nContextValue): string {
  const { t, tp, formatNumber } = i18n
  const parts: string[] = [tp("plural.items", meals.length)]
  const kcal = meals.reduce((acc, m) => acc + m.calories, 0)
  const protein = meals.reduce((acc, m) => acc + m.protein, 0)
  if (kcal > 0) parts.push(`${formatNumber(kcal)} ${t("common.kcal")}`)
  if (protein > 0) parts.push(`${formatNumber(protein)} ${t("common.gProtein")}`)
  return parts.join(" · ")
}

function DarkMealSection({
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
  const i18n = useI18n()
  const { t } = i18n
  const label = t(`mealType.${type}`)
  const [customOpen, setCustomOpen] = React.useState(false)
  const [pickerOpen, setPickerOpen] = React.useState(false)

  return (
    <div className="rounded-2xl border border-white/[0.07] bg-white/[0.03] px-5 sm:px-6">
      <div className="flex items-center justify-between gap-3 border-b border-white/[0.06] py-3.5">
        <div className="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-1">
          <h2 className="font-heading text-base font-semibold tracking-tight text-white/90">
            {label}
          </h2>
          <span className="font-mono text-xs text-white/40">{sectionSubtotal(meals, i18n)}</span>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              aria-label={t("today.addSection", { section: label })}
              className="grid size-7 shrink-0 place-items-center rounded-md text-white/50 transition-colors hover:bg-white/10 hover:text-white"
            >
              <Plus className="size-4" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="min-w-44">
            <DropdownMenuItem onSelect={() => setCustomOpen(true)}>
              <Plus className="size-4" /> {t("today.newCustomMeal")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => setPickerOpen(true)}>
              <BookOpen className="size-4" /> {t("today.fromLibrary")}
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
        <div className="py-4 font-mono text-xs text-white/35">
          {t("today.nothingLogged", { section: label })}
        </div>
      ) : (
        <AnimatePresence initial={false}>
          {meals.map((meal) => (
            <DarkMealRow
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

/* --- page --------------------------------------------------------------- */

export function Today() {
  const { meals, loading, addMeal, deleteMeal, dropMeal, reload } = useMeals()
  const targets = useTargets()
  const { t, formatDate } = useI18n()

  const comingSoon = (feature: string) => toast(t("common.comingSoon", { feature }))

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

  const today = formatDate(new Date(), {
    weekday: "long",
    month: "short",
    day: "numeric",
  })

  return (
    // Full-bleed dark surface: break out of the light shell's padding.
    <div className="-mx-4 -my-5 min-h-screen bg-[#0b0d11] px-4 py-8 text-white sm:-mx-8 sm:-my-8 sm:px-8 sm:py-10 lg:-mx-10 lg:px-10">
      <div className="mx-auto flex max-w-2xl flex-col gap-9">
        {/* Masthead */}
        <motion.header {...fade()} className="text-center">
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.2em]" style={{ color: GREEN }}>
            {today}
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-white">
            {t("today.title")}
          </h1>
          <p className="mt-2 text-sm text-white/45">{t("today.subtitle")}</p>
        </motion.header>

        {/* Rings hero */}
        <motion.section {...fade(0.05)}>
          <TodayRings {...totals} goals={targets} />
        </motion.section>

        {/* Log toolbar */}
        <motion.div {...fade(0.1)} className="flex flex-wrap items-center justify-center gap-2">
          <AddMealDialog
            onAdd={addMeal}
            trigger={<DarkAction icon={Plus} label={t("today.addMeal")} primary />}
          />
          <AiMealLookupDialog
            trigger={<DarkAction icon={Sparkles} label={t("today.aiLookup")} />}
          />
          <DarkAction
            icon={Camera}
            label={t("today.photo")}
            onClick={() => comingSoon(t("feature.photoLog"))}
          />
          <DarkAction
            icon={Barcode}
            label={t("today.scan")}
            onClick={() => comingSoon(t("feature.barcodeScan"))}
          />
          <DarkAction
            icon={RotateCcw}
            label={t("today.repeat")}
            onClick={() => comingSoon(t("feature.repeatYesterday"))}
          />
        </motion.div>

        {/* Sections */}
        {loading ? (
          <div className="flex flex-col gap-4">
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                className="h-28 animate-pulse rounded-2xl border border-white/[0.06] bg-white/[0.03]"
                style={{ opacity: 1 - i * 0.2 }}
              />
            ))}
          </div>
        ) : (
          <motion.section {...fade(0.15)} className="flex flex-col gap-4">
            {MEAL_TYPE_ORDER.map((type) => (
              <DarkMealSection
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
    </div>
  )
}

export default Today
