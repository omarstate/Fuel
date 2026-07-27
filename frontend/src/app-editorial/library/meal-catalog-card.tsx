import * as React from "react"
import { motion } from "framer-motion"
import { useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { Pencil, Trash2 } from "lucide-react"
import { deleteCatalogMeal, type CatalogMeal } from "@/lib/api"
import { useMe, canEditMeal } from "@/app-editorial/use-me"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"
import { ConfirmDialog } from "@/app-editorial/library/confirm-dialog"
import { AddToLogButton } from "@/app-editorial/add-to-log-button"
import { MorphButton } from "@/components/ui/morph-button"
import { cn } from "@/lib/utils"

export function MealCatalogCard({
  meal,
  onChanged,
  delay = 0,
}: {
  meal: CatalogMeal
  /** Called after a successful edit or delete so the caller can refresh its list. */
  onChanged?: () => void
  delay?: number
}) {
  const [confirmOpen, setConfirmOpen] = React.useState(false)
  const navigate = useNavigate()
  const me = useMe()
  const canEdit = canEditMeal(meal, me)

  async function handleDelete(): Promise<boolean> {
    try {
      await deleteCatalogMeal(meal.id)
      return true
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't delete that meal.")
      return false
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay }}
      onClick={() => navigate(`/dashboard/library/${meal.id}`)}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault()
          navigate(`/dashboard/library/${meal.id}`)
        }
      }}
      className="group relative flex min-w-0 cursor-pointer flex-col justify-between gap-4 rounded-xl border border-border bg-card p-5 transition-all hover:border-[var(--accent-ink)]/40 hover:shadow-md"
    >
      {canEdit && (
        <div
          className="absolute right-3 top-3 z-10 flex items-center gap-1.5 opacity-100 transition-opacity sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100"
          onClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => e.stopPropagation()}
        >
          <AddCatalogMealDialog
            meal={meal}
            onSaved={() => onChanged?.()}
            trigger={
              <button
                type="button"
                aria-label={`Edit ${meal.name}`}
                className="grid size-9 place-items-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground sm:size-7"
              >
                <Pencil className="size-4 sm:size-3.5" />
              </button>
            }
          />
          <button
            type="button"
            aria-label={`Delete ${meal.name}`}
            onClick={() => setConfirmOpen(true)}
            className="grid size-9 place-items-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:border-destructive/40 hover:text-destructive sm:size-7"
          >
            <Trash2 className="size-4 sm:size-3.5" />
          </button>
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Delete meal"
        message={`Delete "${meal.name}" from the catalog? This can't be undone.`}
        onConfirm={() => {}}
        confirmSlot={
          <MorphButton
            intent="destructive"
            idleLabel="Delete"
            loadingLabel="Deleting…"
            successLabel="Deleted"
            onAction={handleDelete}
            onSuccess={() => {
              setConfirmOpen(false)
              onChanged?.()
            }}
          />
        }
      />

      <div className={canEdit ? "pr-20 sm:pr-0" : ""}>
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="truncate text-[0.95rem] font-medium text-foreground">
              {meal.name}
            </div>
            {(meal.category || meal.servingSize) && (
              <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
                {meal.category && (
                  <span className="rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-[var(--accent-ink)]">
                    {meal.category.name}
                  </span>
                )}
                {meal.aiSource === "estimate" ? (
                  <span className="rounded-md bg-amber-500/15 px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-amber-700 dark:text-amber-400">
                    AI estimate
                  </span>
                ) : meal.aiSource === "official" ? (
                  <span className="rounded-md bg-muted px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-muted-foreground">
                    AI
                  </span>
                ) : null}
                {meal.servingSize && (
                  <span className="font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
                    {meal.servingSize}
                  </span>
                )}
              </div>
            )}

            {meal.description && (
              <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
                {meal.description}
              </p>
            )}
          </div>

          {/* Calories — the headline stat, pinned top-right. Fades on hover for
              editable meals so the edit/delete overlay can take the corner. */}
          <div
            className={cn(
              "shrink-0 text-right",
              canEdit &&
                "transition-opacity sm:group-hover:opacity-0 sm:group-focus-within:opacity-0"
            )}
          >
            <div className="font-mono text-xl font-semibold leading-none text-foreground">
              {meal.aiSource === "estimate" ? "~" : ""}
              {meal.calories}
            </div>
            <div className="mt-1 font-mono text-[0.6rem] uppercase tracking-widest text-muted-foreground">
              kcal
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-x-3 overflow-hidden font-mono text-xs whitespace-nowrap text-muted-foreground">
          <span>
            <span className="text-[#b5431c]">P</span> {meal.protein}
          </span>
          <span>
            <span className="text-[#a9781f]">C</span> {meal.carbs}
          </span>
          <span>
            <span className="text-[#5c6d0a]">F</span> {meal.fat}
          </span>
        </div>

        <div
          className="shrink-0"
          onClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => e.stopPropagation()}
        >
          <AddToLogButton meal={meal} className="sm:text-xs" />
        </div>
      </div>
    </motion.div>
  )
}
