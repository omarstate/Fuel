import * as React from "react"
import { motion } from "framer-motion"
import { useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { Plus, Pencil, Trash2 } from "lucide-react"
import { deleteCatalogMeal, type CatalogMeal } from "@/lib/api"
import { useMe, canEditMeal } from "@/app-editorial/use-me"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"
import { ConfirmDialog } from "@/app-editorial/library/confirm-dialog"

export function MealCatalogCard({
  meal,
  onAdd,
  onChanged,
  delay = 0,
}: {
  meal: CatalogMeal
  onAdd: (meal: CatalogMeal) => void
  /** Called after a successful edit or delete so the caller can refresh its list. */
  onChanged?: () => void
  delay?: number
}) {
  const [adding, setAdding] = React.useState(false)
  const [confirmOpen, setConfirmOpen] = React.useState(false)
  const [deleting, setDeleting] = React.useState(false)
  const navigate = useNavigate()
  const me = useMe()
  const canEdit = canEditMeal(meal, me)

  async function handleAdd(e: React.MouseEvent) {
    e.preventDefault()
    e.stopPropagation()
    if (adding) return
    setAdding(true)
    try {
      await onAdd(meal)
    } finally {
      setAdding(false)
    }
  }

  async function handleDelete() {
    setDeleting(true)
    try {
      await deleteCatalogMeal(meal.id)
      toast.success(`${meal.name} deleted`)
      setConfirmOpen(false)
      onChanged?.()
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't delete that meal.")
    } finally {
      setDeleting(false)
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
      className="group relative flex cursor-pointer flex-col justify-between gap-4 rounded-xl border border-border bg-card p-5 transition-all hover:border-[var(--accent-ink)]/40 hover:shadow-md"
    >
      {canEdit && (
        <div
          className="absolute right-3 top-3 z-10 flex items-center gap-1 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100"
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
                className="grid size-7 place-items-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground"
              >
                <Pencil className="size-3.5" />
              </button>
            }
          />
          <button
            type="button"
            aria-label={`Delete ${meal.name}`}
            onClick={() => setConfirmOpen(true)}
            className="grid size-7 place-items-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:border-destructive/40 hover:text-destructive"
          >
            <Trash2 className="size-3.5" />
          </button>
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Delete meal"
        message={`Delete "${meal.name}" from the catalog? This can't be undone.`}
        loading={deleting}
        onConfirm={handleDelete}
      />

      <div>
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="truncate text-[0.95rem] font-medium text-foreground">
              {meal.name}
            </div>
            {meal.servingSize && (
              <div className="mt-0.5 font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
                {meal.servingSize}
              </div>
            )}
          </div>
          {meal.category && (
            <span
              className={`shrink-0 rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-[var(--accent-ink)] ${
                canEdit
                  ? "transition-opacity duration-150 group-hover:opacity-0 group-focus-within:opacity-0"
                  : ""
              }`}
            >
              {meal.category.name}
            </span>
          )}
        </div>

        {meal.description && (
          <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
            {meal.description}
          </p>
        )}
      </div>

      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 font-mono text-xs text-muted-foreground">
          <span className="text-sm font-semibold text-foreground">
            {meal.calories}
            <span className="ml-1 text-[0.65rem] font-normal text-muted-foreground">
              kcal
            </span>
          </span>
          <span>
            <span className="text-[#b5431c]">P</span> {meal.protein}
          </span>
          <span>
            <span className="text-[#a9781f]">C</span> {meal.carbs}
          </span>
          <span>
            <span className="text-[#57783a]">F</span> {meal.fat}
          </span>
        </div>

        <button
          type="button"
          onClick={handleAdd}
          disabled={adding}
          className="inline-flex shrink-0 items-center gap-1.5 rounded-lg bg-[#14120f] px-3 py-1.5 text-xs font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:opacity-60"
        >
          <Plus className="size-3.5" />
          {adding ? "Adding…" : "Add to today"}
        </button>
      </div>
    </motion.div>
  )
}
