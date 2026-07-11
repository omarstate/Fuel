import * as React from "react"
import { motion } from "framer-motion"
import { Plus, ChefHat, RotateCcw } from "lucide-react"
import { getMyMeals, createCatalogMeal, type CatalogMeal, type CreateCatalogMealInput } from "@/lib/api"
import { useAddCatalogMealToLog } from "@/app-editorial/library/use-catalog"
import { MealCatalogCard } from "@/app-editorial/library/meal-catalog-card"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function LoadingGrid() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          className="h-40 animate-pulse rounded-xl border border-border bg-muted"
          style={{ opacity: 1 - (i % 3) * 0.15 }}
        />
      ))}
    </div>
  )
}

export function MyMeals() {
  const [meals, setMeals] = React.useState<CatalogMeal[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const addCatalogMealToLog = useAddCatalogMealToLog()

  const refresh = React.useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await getMyMeals()
      setMeals(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.")
    } finally {
      setLoading(false)
    }
  }, [])

  React.useEffect(() => {
    refresh()
  }, [refresh])

  const createMeal = React.useCallback(
    async (input: CreateCatalogMealInput) => {
      const meal = await createCatalogMeal(input)
      await refresh()
      return meal
    },
    [refresh]
  )

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      {/* Masthead */}
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Nutrition · My Meals
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            My meals
          </h1>
          <p className="mt-1.5 max-w-md text-sm text-muted-foreground">
            The meals you've contributed to the catalog. Edit or remove them any time.
          </p>
        </div>
        <AddCatalogMealDialog
          onCreate={createMeal}
          trigger={
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              <Plus className="size-4" /> Add meal
            </button>
          }
        />
      </motion.header>

      {/* Content */}
      <motion.section {...fade(0.1)} className="flex flex-col gap-6">
        {error ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <ChefHat className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">Couldn't reach the Fuel API</div>
              <p className="mt-1 max-w-sm text-sm text-muted-foreground">
                Start the backend with{" "}
                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-foreground">
                  cd backend &amp;&amp; npm run dev
                </code>{" "}
                and try again.
              </p>
            </div>
            <button
              type="button"
              onClick={() => refresh()}
              className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              <RotateCcw className="size-4" /> Retry
            </button>
          </div>
        ) : loading ? (
          <LoadingGrid />
        ) : meals.length === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <ChefHat className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">
                You haven't added any meals yet
              </div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Meals you contribute to the shared catalog will show up here.
              </p>
            </div>
            <AddCatalogMealDialog
              onCreate={createMeal}
              trigger={
                <button
                  type="button"
                  className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
                >
                  <Plus className="size-4" /> Add a meal
                </button>
              }
            />
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {meals.map((meal, i) => (
              <MealCatalogCard
                key={meal.id}
                meal={meal}
                onAdd={addCatalogMealToLog}
                onChanged={refresh}
                delay={Math.min(i, 6) * 0.03}
              />
            ))}
          </div>
        )}
      </motion.section>
    </div>
  )
}

export default MyMeals
