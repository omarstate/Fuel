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
import { useAddCatalogMealToLog } from "@/app-editorial/library/use-catalog"
import type { CatalogMeal } from "@/lib/api"
import {
  MEAL_TYPE_ORDER,
  mealTypeLabel,
  suggestedMealType,
  type MealType,
} from "@/app/nutrition/types"

/** Section-picking replacement for the plain "Add to today" MorphButton. Idle
 * renders a dropdown of the four meal sections (the time-of-day suggestion
 * first); selecting one runs the shared catalog→log insert and morphs the pill
 * in place through loading → Logged / Failed, then resets to idle. */
export function AddToLogButton({
  meal,
  className,
  idleLabel = "Add to today",
  onLogged,
}: {
  meal: CatalogMeal
  className?: string
  idleLabel?: string
  /** Fired once, right after a successful log lands (before the reset delay).
   * Additive — callers that don't pass it keep the original behavior. */
  onLogged?: () => void
}) {
  const addToLog = useAddCatalogMealToLog()
  const [status, setStatus] = React.useState<Status>("idle")

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

  async function handleSelect(type: MealType) {
    if (status !== "idle") return
    setStatus("loading")
    let ok = false
    try {
      ok = await addToLog(meal, type)
    } catch {
      ok = false
    }
    setStatus(ok ? "success" : "error")
    if (ok) onLogged?.()
    resetTimer.current = setTimeout(() => {
      setStatus("idle")
    }, 1300)
  }

  if (status !== "idle") {
    const label = status === "loading" ? "Adding…" : status === "success" ? "Logged" : "Failed"
    return (
      <button
        type="button"
        disabled
        aria-label={idleLabel}
        className={cn("inline-flex shrink-0 cursor-not-allowed", className)}
      >
        <BadgeMorph status={status} label={label} />
      </button>
    )
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          className={cn(
            "inline-flex shrink-0 items-center gap-2 rounded-full bg-[#14120f] px-3.5 py-2.5 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 sm:px-3 sm:py-1.5 sm:text-[13px]",
            className
          )}
        >
          <Plus className="size-4 sm:size-3.5" />
          {idleLabel}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-40">
        {order.map((type) => (
          <DropdownMenuItem key={type} onSelect={() => void handleSelect(type)}>
            {mealTypeLabel[type]}
            {type === suggested && (
              <span className="ml-auto font-mono text-[0.65rem] uppercase tracking-wide text-muted-foreground">
                suggested
              </span>
            )}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
