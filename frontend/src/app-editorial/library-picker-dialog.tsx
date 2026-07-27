import * as React from "react"
import { Search } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { MorphButton } from "@/components/ui/morph-button"
import { usePagedMeals } from "@/app-editorial/library/use-paged-meals"
import { useAddCatalogMealToLog } from "@/app-editorial/library/use-catalog"
import { Plus } from "lucide-react"
import { type MealType } from "@/app/nutrition/types"
import { useI18n } from "@/lib/i18n"
import type { CatalogMeal } from "@/lib/api"

function PickerRow({
  meal,
  mealType,
  onLogged,
}: {
  meal: CatalogMeal
  mealType: MealType
  onLogged?: () => void
}) {
  const { t, formatNumber } = useI18n()
  const addToLog = useAddCatalogMealToLog()
  const meta = [meal.servingSize, meal.category?.name].filter(Boolean).join(" · ")

  return (
    <div className="flex items-center justify-between gap-3 border-b border-border py-2.5 last:border-b-0">
      <div className="min-w-0">
        <div className="truncate text-sm font-medium text-foreground">{meal.name}</div>
        {meta && (
          <div className="mt-0.5 truncate font-mono text-[0.65rem] uppercase tracking-wide text-muted-foreground">
            {meta}
          </div>
        )}
      </div>
      <div className="flex shrink-0 items-center gap-3">
        <div className="text-end">
          <span className="font-mono text-sm font-semibold text-foreground">
            {meal.aiSource === "estimate" ? "~" : ""}
            {formatNumber(meal.calories)}
          </span>{" "}
          <span className="font-mono text-[0.6rem] uppercase tracking-widest text-muted-foreground">
            {t("common.kcal")}
          </span>
        </div>
        <MorphButton
          variant="pill"
          idleIcon={Plus}
          idleLabel={t("common.add")}
          loadingLabel={t("common.adding")}
          successLabel={t("addToLog.logged")}
          resetDelay={900}
          onAction={() => addToLog(meal, mealType)}
          onSuccess={onLogged}
        />
      </div>
    </div>
  )
}

export function LibraryPickerDialog({
  mealType,
  trigger,
  open: controlledOpen,
  onOpenChange: controlledOnOpenChange,
  onLogged,
}: {
  mealType: MealType
  /** Optional when driven via the controlled `open` API below. */
  trigger?: React.ReactNode
  /** Controlled open API — when provided, overrides the internal open state. */
  open?: boolean
  onOpenChange?: (open: boolean) => void
  /** Fired after each successful add (fire-and-forget), so Today can reload. */
  onLogged?: () => void
}) {
  const [internalOpen, setInternalOpen] = React.useState(false)
  const isControlled = controlledOpen !== undefined
  const open = isControlled ? controlledOpen : internalOpen
  const [search, setSearch] = React.useState("")
  const setOpen = React.useCallback(
    (next: boolean) => {
      // Reset the query each time the dialog closes.
      if (!next) setSearch("")
      if (isControlled) controlledOnOpenChange?.(next)
      else setInternalOpen(next)
    },
    [isControlled, controlledOnOpenChange]
  )

  const { t } = useI18n()
  const { meals, loading, loadingMore, hasMore, loadMore } = usePagedMeals({
    search,
    pageSize: 8,
  })

  const label = t(`mealType.${mealType}`)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      {trigger && <DialogTrigger asChild>{trigger}</DialogTrigger>}
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            {t("picker.fromLibrary")}
          </div>
          <DialogTitle className="font-heading text-lg">{t("picker.addTo", { section: label })}</DialogTitle>
          <DialogDescription>
            {t("picker.description")}
          </DialogDescription>
        </DialogHeader>

        <div className="relative">
          <Search className="pointer-events-none absolute start-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("picker.searchMeals")}
            className="h-9 ps-8"
            autoFocus
          />
        </div>

        <div className="max-h-[60vh] overflow-y-auto">
          {loading ? (
            <div className="flex flex-col gap-2 py-1">
              {[0, 1, 2, 3].map((i) => (
                <div
                  key={i}
                  className="h-12 animate-pulse rounded-lg bg-muted"
                  style={{ opacity: 1 - i * 0.18 }}
                />
              ))}
            </div>
          ) : meals.length === 0 ? (
            <div className="rounded-lg border border-border bg-card px-4 py-8 text-center text-sm text-muted-foreground">
              {t("picker.noMatch")}
            </div>
          ) : (
            <>
              {meals.map((meal) => (
                <PickerRow
                  key={meal.id}
                  meal={meal}
                  mealType={mealType}
                  onLogged={onLogged}
                />
              ))}
              {hasMore && (
                <div className="flex justify-center pt-3">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => loadMore()}
                    disabled={loadingMore}
                  >
                    {t("common.showMore")}
                  </Button>
                </div>
              )}
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
