import * as React from "react"
import { Plus } from "lucide-react"
import { cn } from "@/lib/utils"
import { BadgeMorph, type Status } from "@/components/ui/badge-morph"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover"
import { Stepper } from "@/components/ui/stepper"
import { useAddCatalogMealToLog } from "@/app-editorial/library/use-catalog"
import { parseServingGrams } from "@/app-editorial/label-portion"
import { useI18n } from "@/lib/i18n"
import type { CatalogMeal } from "@/lib/api"
import {
  MEAL_TYPE_ORDER,
  suggestedMealType,
  type MealType,
} from "@/app/nutrition/types"

const round2 = (n: number) => Math.round(n * 100) / 100
const fmtServings = (n: number) => (Number.isInteger(n) ? String(n) : String(round2(n)))

const SERVING_CHIPS = [
  { label: "½", value: 0.5 },
  { label: "1", value: 1 },
  { label: "2", value: 2 },
] as const

/** Section-picking replacement for the plain "Add to today" MorphButton. Idle
 * renders a dropdown of the four meal sections (the time-of-day suggestion
 * first); picking one opens a portion popover anchored to the pill (servings +
 * optional grams). Logging runs the shared catalog→log insert and morphs the
 * pill in place through loading → Logged / Failed, then resets to idle. */
export function AddToLogButton({
  meal,
  className,
  idleLabel,
  onLogged,
}: {
  meal: CatalogMeal
  className?: string
  idleLabel?: string
  /** Fired once, right after a successful log lands (before the reset delay).
   * Additive — callers that don't pass it keep the original behavior. */
  onLogged?: () => void
}) {
  const { t, tp, formatNumber } = useI18n()
  const resolvedIdleLabel = idleLabel ?? t("addToLog.addToToday")
  const addToLog = useAddCatalogMealToLog()
  const [status, setStatus] = React.useState<Status>("idle")
  const [pendingType, setPendingType] = React.useState<MealType | null>(null)
  const [servings, setServings] = React.useState("1")
  const [grams, setGrams] = React.useState("")

  const gramsPerServing = React.useMemo(
    () => parseServingGrams(meal.servingSize),
    [meal.servingSize]
  )

  const resetTimer = React.useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  React.useEffect(() => {
    return () => {
      if (resetTimer.current) clearTimeout(resetTimer.current)
    }
  }, [])

  const suggested = suggestedMealType()
  const order: MealType[] = [
    suggested,
    ...MEAL_TYPE_ORDER.filter((t) => t !== suggested),
  ]

  function openPortion(type: MealType) {
    setPendingType(type)
    setServings("1")
    setGrams(gramsPerServing !== null ? String(gramsPerServing) : "")
  }

  function onPopoverChange(open: boolean) {
    if (!open) setPendingType(null)
  }

  // Servings is authoritative; grams is a display alias synced via the serving
  // size when one is known.
  function setServingsSynced(v: string) {
    setServings(v)
    if (gramsPerServing !== null) {
      const n = Number(v)
      setGrams(v.trim() === "" || !Number.isFinite(n) ? "" : String(Math.round(n * gramsPerServing)))
    }
  }

  function setGramsSynced(v: string) {
    setGrams(v)
    if (gramsPerServing !== null) {
      const g = Number(v)
      setServings(v.trim() === "" || !Number.isFinite(g) ? "" : fmtServings(g / gramsPerServing))
    }
  }

  function stepServings(dir: 1 | -1) {
    const cur = Number(servings) || 0
    const next = Math.min(50, Math.max(0.5, cur + dir * 0.5))
    setServingsSynced(fmtServings(next))
  }

  const factor = Number(servings) || 0
  const preview = {
    calories: Math.round(meal.calories * factor),
    protein: Math.round(meal.protein * factor),
    carbs: Math.round(meal.carbs * factor),
    fat: Math.round(meal.fat * factor),
  }

  async function handleLog() {
    if (!pendingType || factor <= 0) return
    const type = pendingType
    const servingSize =
      gramsPerServing !== null
        ? `${grams} ${t("common.g")}`
        : meal.servingSize
          ? `${servings} × ${meal.servingSize}`
          : tp("addToLog.servingsUnit", Number(servings) || 0, { count: servings })
    setPendingType(null)
    setStatus("loading")
    let ok = false
    try {
      ok = await addToLog(meal, type, { factor, servingSize })
    } catch {
      ok = false
    }
    setStatus(ok ? "success" : "error")
    if (ok) onLogged?.()
    resetTimer.current = setTimeout(() => {
      setStatus("idle")
    }, 1300)
  }

  const label =
    status === "loading"
      ? t("common.adding")
      : status === "success"
        ? t("addToLog.logged")
        : t("common.error")

  return (
    <Popover open={pendingType !== null} onOpenChange={onPopoverChange}>
      {status !== "idle" ? (
        <PopoverAnchor asChild>
          <button
            type="button"
            disabled
            aria-label={resolvedIdleLabel}
            className={cn("inline-flex shrink-0 cursor-not-allowed", className)}
          >
            <BadgeMorph status={status} label={label} />
          </button>
        </PopoverAnchor>
      ) : (
        <DropdownMenu>
          <PopoverAnchor asChild>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                className={cn(
                  "inline-flex shrink-0 items-center gap-2 rounded-full bg-[#14120f] px-3.5 py-2.5 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 sm:px-3 sm:py-1.5 sm:text-[13px]",
                  className
                )}
              >
                <Plus className="size-4 sm:size-3.5" />
                {resolvedIdleLabel}
              </button>
            </DropdownMenuTrigger>
          </PopoverAnchor>
          <DropdownMenuContent align="end" className="min-w-40">
            {order.map((type) => (
              <DropdownMenuItem key={type} onSelect={() => openPortion(type)}>
                {t(`mealType.${type}`)}
                {type === suggested && (
                  <span className="ms-auto font-mono text-[0.65rem] uppercase tracking-wide text-muted-foreground">
                    {t("addToLog.suggested")}
                  </span>
                )}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      <PopoverContent align="end" className="w-64">
        {pendingType && (
          <div className="flex flex-col gap-3">
            <div>
              <p className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                {t(`mealType.${pendingType}`)}
              </p>
              <p className="truncate text-sm font-medium text-foreground">{meal.name}</p>
            </div>

            <Stepper
              label={t("addToLog.servings")}
              unit="±0.5"
              value={servings}
              onChange={setServingsSynced}
              onStep={stepServings}
              inputMode="decimal"
            />

            {gramsPerServing !== null && (
              <label className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  {t("addToLog.grams")}
                </span>
                <Input
                  type="number"
                  inputMode="numeric"
                  min={0}
                  value={grams}
                  onChange={(e) => setGramsSynced(e.target.value)}
                  className="h-9"
                />
              </label>
            )}

            <div className="flex gap-1.5">
              {SERVING_CHIPS.map((c) => (
                <button
                  key={c.value}
                  type="button"
                  onClick={() => setServingsSynced(String(c.value))}
                  className={cn(
                    "rounded-md px-2 py-1 font-mono text-[0.65rem] uppercase tracking-[0.08em] transition-colors",
                    Number(servings) === c.value
                      ? "bg-[var(--accent-tint)] text-[var(--accent-ink)]"
                      : "bg-muted text-muted-foreground hover:text-foreground"
                  )}
                >
                  {c.label}
                </button>
              ))}
            </div>

            <p className="font-mono text-[0.7rem] tabular-nums text-muted-foreground">
              {formatNumber(preview.calories)} {t("common.kcal")} · {formatNumber(preview.protein)}P · {formatNumber(preview.carbs)}C · {formatNumber(preview.fat)}F
            </p>

            <button
              type="button"
              onClick={() => void handleLog()}
              disabled={factor <= 0}
              className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-[#14120f] px-3 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Plus className="size-4" />
              {t("addToLog.log")}
            </button>
          </div>
        )}
      </PopoverContent>
    </Popover>
  )
}
