import * as React from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
import { motion } from "framer-motion"
import { toast } from "sonner"
import {
  ArrowLeft,
  BookOpen,
  Plus,
  Pencil,
  Trash2,
  RotateCcw,
  Flame,
  Repeat,
  Users,
  Clock,
  Gauge,
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import { useAuth } from "@/lib/auth"
import { getMealDetail, deleteCatalogMeal, type CatalogMealDetail } from "@/lib/api"
import { GOALS } from "@/app-editorial/macro-summary"
import { StatCard } from "@/app-editorial/stat-card"
import { useMe, canEditMeal } from "@/app-editorial/use-me"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"
import { ConfirmDialog } from "@/app-editorial/library/confirm-dialog"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

const macroMeta = [
  { key: "protein", label: "Protein", color: "#ff6b35", kcalPerGram: 4 },
  { key: "carbs", label: "Carbs", color: "#d9a441", kcalPerGram: 4 },
  { key: "fat", label: "Fat", color: "#6f9e4a", kcalPerGram: 9 },
] as const

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  })
}

function relativeTime(iso: string | null) {
  if (!iso) return "Never"
  const then = new Date(iso).getTime()
  const now = Date.now()
  const diffMs = now - then
  const diffSec = Math.round(diffMs / 1000)
  if (diffSec < 60) return "Just now"
  const diffMin = Math.round(diffSec / 60)
  if (diffMin < 60) return `${diffMin}m ago`
  const diffHour = Math.round(diffMin / 60)
  if (diffHour < 24) return `${diffHour}h ago`
  const diffDay = Math.round(diffHour / 24)
  if (diffDay < 7) return `${diffDay}d ago`
  const diffWeek = Math.round(diffDay / 7)
  if (diffWeek < 5) return `${diffWeek}w ago`
  const diffMonth = Math.round(diffDay / 30)
  if (diffMonth < 12) return `${diffMonth}mo ago`
  const diffYear = Math.round(diffDay / 365)
  return `${diffYear}y ago`
}

function LoadingSkeleton() {
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div className="h-4 w-24 animate-pulse rounded bg-muted" />
      <div className="flex flex-col gap-2 border-b border-border pb-6">
        <div className="h-4 w-32 animate-pulse rounded bg-muted" />
        <div className="h-10 w-2/3 animate-pulse rounded bg-muted" />
        <div className="h-4 w-48 animate-pulse rounded bg-muted" />
      </div>
      <div className="h-40 animate-pulse rounded-xl border border-border bg-muted" />
      <div className="h-32 animate-pulse rounded-xl border border-border bg-muted" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className="h-28 animate-pulse rounded-xl border border-border bg-muted"
            style={{ opacity: 1 - (i % 4) * 0.12 }}
          />
        ))}
      </div>
    </div>
  )
}

function ErrorState({
  message,
  onRetry,
}: {
  message: string
  onRetry?: () => void
}) {
  const isNetworkError = message.toLowerCase().includes("couldn't reach")
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <Link
        to="/dashboard/library"
        className="inline-flex w-fit items-center gap-1.5 font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="size-3.5" /> Library
      </Link>
      <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
        <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
          <BookOpen className="size-5" />
        </span>
        <div>
          <div className="font-medium text-foreground">
            {isNetworkError ? "Couldn't reach the Fuel API" : "Meal not found"}
          </div>
          <p className="mt-1 max-w-sm text-sm text-muted-foreground">
            {isNetworkError ? (
              <>
                Start the backend with{" "}
                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-foreground">
                  cd backend &amp;&amp; npm run dev
                </code>{" "}
                and try again.
              </>
            ) : (
              "This meal may have been removed from the catalog."
            )}
          </p>
        </div>
        <div className="mt-1 flex items-center gap-2">
          {onRetry && (
            <button
              type="button"
              onClick={onRetry}
              className="inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              <RotateCcw className="size-4" /> Retry
            </button>
          )}
          <Link
            to="/dashboard/library"
            className="inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-muted"
          >
            Back to Library
          </Link>
        </div>
      </div>
    </div>
  )
}

export function MealDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { user } = useAuth()
  const me = useMe()
  const [meal, setMeal] = React.useState<CatalogMealDetail | null>(null)
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const [adding, setAdding] = React.useState(false)
  const [confirmOpen, setConfirmOpen] = React.useState(false)
  const [deleting, setDeleting] = React.useState(false)

  const load = React.useCallback(() => {
    if (!id) return
    setLoading(true)
    setError(null)
    getMealDetail(id)
      .then((data) => setMeal(data))
      .catch((err) => {
        setError(err instanceof Error ? err.message : "Something went wrong.")
      })
      .finally(() => setLoading(false))
  }, [id])

  React.useEffect(() => {
    load()
  }, [load])

  async function handleAdd() {
    if (!meal || adding) return
    if (!user) {
      toast.error("Sign in to log meals.")
      return
    }
    setAdding(true)
    try {
      const { error: insertError } = await supabase.from("meals").insert({
        id: crypto.randomUUID(),
        user_id: user.id,
        name: meal.name,
        meal_type: "lunch",
        serving_size: meal.servingSize ?? null,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        logged_at: new Date().toISOString(),
        catalog_meal_id: meal.id,
      })
      if (insertError) {
        toast.error(`Couldn't add ${meal.name} to today's log.`)
        return
      }
      toast.success(`${meal.name} added to today's log`)
      setMeal((prev) =>
        prev
          ? {
              ...prev,
              stats: {
                ...prev.stats,
                loggedToday: prev.stats.loggedToday + 1,
                loggedTotal: prev.stats.loggedTotal + 1,
                lastLoggedAt: new Date().toISOString(),
              },
            }
          : prev
      )
    } finally {
      setAdding(false)
    }
  }

  async function handleDelete() {
    if (!meal) return
    setDeleting(true)
    try {
      await deleteCatalogMeal(meal.id)
      toast.success(`${meal.name} deleted`)
      navigate("/dashboard/library")
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't delete that meal.")
    } finally {
      setDeleting(false)
    }
  }

  if (loading) return <LoadingSkeleton />
  if (error) return <ErrorState message={error} onRetry={load} />
  if (!meal)
    return (
      <ErrorState message="Meal not found" />
    )

  const canEdit = canEditMeal(meal, me)

  const totalKcalFromMacros =
    meal.protein * 4 + meal.carbs * 4 + meal.fat * 9

  const splitBase = totalKcalFromMacros > 0 ? totalKcalFromMacros : meal.calories || 1

  const macroSplit = macroMeta.map((m) => {
    const grams = meal[m.key as "protein" | "carbs" | "fat"]
    const kcal = grams * m.kcalPerGram
    const pct = (kcal / splitBase) * 100
    return { ...m, grams, kcal, pct }
  })

  const proteinDensity = Math.round(
    (meal.protein / Math.max(meal.calories, 1)) * 100
  )

  const hasStats =
    meal.stats.loggedToday > 0 ||
    meal.stats.loggedTotal > 0 ||
    meal.stats.uniqueLoggers > 0

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <motion.div {...fade()}>
        <Link
          to="/dashboard/library"
          className="inline-flex w-fit items-center gap-1.5 font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="size-3.5" /> Library
        </Link>
      </motion.div>

      {/* Header */}
      <motion.header
        {...fade(0.05)}
        className="flex flex-col gap-2 border-b border-border pb-6"
      >
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-2">
            {meal.category && (
              <span className="w-fit rounded-md bg-[var(--accent-tint)] px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-[var(--accent-ink)]">
                {meal.category.name}
              </span>
            )}
            <h1 className="font-heading text-4xl font-semibold tracking-tight text-foreground">
              {meal.name}
            </h1>
          </div>
          {canEdit && (
            <div className="flex shrink-0 items-center gap-2">
              <AddCatalogMealDialog
                meal={meal}
                onSaved={load}
                trigger={
                  <button
                    type="button"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs font-medium text-foreground transition-colors hover:bg-muted"
                  >
                    <Pencil className="size-3.5" /> Edit
                  </button>
                }
              />
              <button
                type="button"
                onClick={() => setConfirmOpen(true)}
                className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-xs font-medium text-destructive transition-colors hover:bg-destructive/10"
              >
                <Trash2 className="size-3.5" /> Delete
              </button>
            </div>
          )}
        </div>
        <p className="text-sm text-muted-foreground">
          Added {formatDate(meal.createdAt)} · by{" "}
          {meal.creator.system ? "Fuel Team" : meal.creator.name}
        </p>
        {meal.description && (
          <p className="mt-1 max-w-xl text-sm text-muted-foreground">{meal.description}</p>
        )}
      </motion.header>

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Delete meal"
        message={`Delete "${meal.name}" from the catalog? This can't be undone.`}
        loading={deleting}
        onConfirm={handleDelete}
      />

      {/* Hero: calories + serving vs. calorie-split bar */}
      <motion.div
        {...fade(0.1)}
        className="grid gap-8 rounded-xl border border-border bg-card p-6 sm:grid-cols-[auto_1fr] sm:p-8"
      >
        <div className="flex flex-col justify-center">
          <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
            Per serving
          </div>
          <div className="mt-1 flex items-baseline gap-1.5">
            <span className="font-mono text-4xl font-semibold leading-none text-foreground">
              {meal.calories}
            </span>
            <span className="font-mono text-sm text-muted-foreground">kcal</span>
          </div>
          {meal.servingSize && (
            <div className="mt-2 text-sm text-muted-foreground">{meal.servingSize}</div>
          )}
        </div>

        <div className="flex flex-col justify-center gap-4 sm:border-l sm:border-border sm:pl-8">
          <div>
            <div className="mb-1.5 font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
              Calorie split
            </div>
            <div className="flex h-3 w-full overflow-hidden rounded-full bg-muted">
              {macroSplit.map((m) => (
                <div
                  key={m.key}
                  style={{ width: `${m.pct}%`, backgroundColor: m.color }}
                  className="h-full first:rounded-l-full last:rounded-r-full"
                />
              ))}
            </div>
          </div>
          <div className="flex flex-wrap gap-x-6 gap-y-2">
            {macroSplit.map((m) => (
              <div key={m.key} className="flex items-center gap-2">
                <span
                  className="size-2.5 rounded-full"
                  style={{ backgroundColor: m.color }}
                />
                <span className="font-mono text-xs text-muted-foreground">
                  {m.label} {m.grams}g
                  <span className="ml-1 text-foreground">
                    ({Math.round(m.pct)}%)
                  </span>
                </span>
              </div>
            ))}
          </div>
        </div>
      </motion.div>

      {/* Nutrition facts */}
      <motion.div
        {...fade(0.15)}
        className="rounded-xl border border-border bg-card p-6"
      >
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          Nutrition facts
        </h2>
        <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <NutritionFact
            label="Calories"
            value={meal.calories}
            unit="kcal"
            pct={Math.round((meal.calories / GOALS.calories) * 100)}
          />
          <NutritionFact
            label="Protein"
            value={meal.protein}
            unit="g"
            color="#ff6b35"
            pct={Math.round((meal.protein / GOALS.protein) * 100)}
          />
          <NutritionFact
            label="Carbs"
            value={meal.carbs}
            unit="g"
            color="#d9a441"
            pct={Math.round((meal.carbs / GOALS.carbs) * 100)}
          />
          <NutritionFact
            label="Fat"
            value={meal.fat}
            unit="g"
            color="#6f9e4a"
            pct={Math.round((meal.fat / GOALS.fat) * 100)}
          />
        </div>
      </motion.div>

      {/* Fun stats */}
      <motion.div {...fade(0.2)} className="flex flex-col gap-3">
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          Fun stats
        </h2>
        {!hasStats && (
          <p className="text-sm text-muted-foreground">
            Nobody's logged this meal yet — be the first.
          </p>
        )}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard
            icon={Flame}
            label="Logged today"
            value={meal.stats.loggedToday}
            hint={meal.stats.loggedToday === 0 ? "Not yet today" : undefined}
          />
          <StatCard
            icon={Repeat}
            label="All-time logs"
            value={meal.stats.loggedTotal}
          />
          <StatCard
            icon={Users}
            label="People logging it"
            value={meal.stats.uniqueLoggers}
          />
          <StatCard
            icon={Clock}
            label="Last logged"
            value={relativeTime(meal.stats.lastLoggedAt)}
          />
          <StatCard
            icon={Gauge}
            label="Protein density"
            value={proteinDensity}
            unit="g/100kcal"
            hint="Higher is leaner"
          />
        </div>
      </motion.div>

      {/* CTA */}
      <motion.div {...fade(0.25)} className="flex justify-end pb-4">
        <button
          type="button"
          onClick={handleAdd}
          disabled={adding}
          className="inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-5 py-2.5 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:opacity-60"
        >
          <Plus className="size-4" />
          {adding ? "Adding…" : "Add to today"}
        </button>
      </motion.div>
    </div>
  )
}

function NutritionFact({
  label,
  value,
  unit,
  pct,
  color,
}: {
  label: string
  value: number
  unit: string
  pct: number
  color?: string
}) {
  return (
    <div>
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.14em] text-muted-foreground">
        {label}
      </div>
      <div className="mt-1 flex items-baseline gap-1">
        <span
          className="font-mono text-xl font-semibold text-foreground"
          style={color ? { color } : undefined}
        >
          {value}
        </span>
        <span className="font-mono text-xs text-muted-foreground">{unit}</span>
      </div>
      <div className="mt-0.5 font-mono text-[0.7rem] text-muted-foreground">
        {pct}% of daily goal
      </div>
    </div>
  )
}

export default MealDetail
