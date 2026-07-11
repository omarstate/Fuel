import * as React from "react"
import { useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { Loader2, Dumbbell } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { getWorkoutCategories, type WorkoutCategory } from "@/lib/api"
import { useSessionActions } from "@/app-editorial/workouts/session/use-session-actions"

/** Modal for picking a workout type and kicking off a new session. This is
 * the entry point into the marquee active-session flow. */
export function StartSessionDialog({ trigger }: { trigger: React.ReactNode }) {
  const [open, setOpen] = React.useState(false)
  const [categories, setCategories] = React.useState<WorkoutCategory[]>([])
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)
  const [pendingId, setPendingId] = React.useState<string | null>(null)
  const navigate = useNavigate()
  const { startSession } = useSessionActions()

  React.useEffect(() => {
    if (!open) return
    let active = true
    setLoading(true)
    setError(null)
    getWorkoutCategories()
      .then((cats) => {
        if (!active) return
        setCategories(cats)
      })
      .catch((err) => {
        if (!active) return
        setError(err instanceof Error ? err.message : "Couldn't load workout types.")
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [open])

  async function handlePick(category: WorkoutCategory) {
    if (pendingId) return
    setPendingId(category.id)
    try {
      const id = await startSession(category)
      if (id) {
        setOpen(false)
        navigate(`/dashboard/workouts/session/${id}`)
      }
    } catch {
      toast.error("Couldn't start that session.")
    } finally {
      setPendingId(null)
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Start a new session</DialogTitle>
          <DialogDescription>Pick what you're training today.</DialogDescription>
        </DialogHeader>

        <div className="mt-2">
          {error ? (
            <div className="rounded-lg border border-border bg-muted/40 px-4 py-6 text-center text-sm text-muted-foreground">
              Couldn't reach the Fuel API. Start the backend and try again.
            </div>
          ) : loading ? (
            <div className="grid grid-cols-2 gap-2.5">
              {[0, 1, 2, 3].map((i) => (
                <div key={i} className="h-14 animate-pulse rounded-lg border border-border bg-muted" />
              ))}
            </div>
          ) : categories.length === 0 ? (
            <div className="rounded-lg border border-border bg-muted/40 px-4 py-6 text-center text-sm text-muted-foreground">
              No workout types yet.
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-2.5">
              {categories.map((cat) => (
                <button
                  key={cat.id}
                  type="button"
                  disabled={pendingId !== null}
                  onClick={() => handlePick(cat)}
                  className="group flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-4 py-3.5 text-left transition-colors hover:border-[var(--accent-ink)]/40 hover:bg-[var(--accent-tint)] disabled:opacity-60"
                >
                  <span className="text-sm font-medium text-foreground">{cat.name}</span>
                  {pendingId === cat.id ? (
                    <Loader2 className="size-4 animate-spin text-[var(--accent-ink)]" />
                  ) : (
                    <Dumbbell className="size-4 text-muted-foreground transition-colors group-hover:text-[var(--accent-ink)]" />
                  )}
                </button>
              ))}
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
