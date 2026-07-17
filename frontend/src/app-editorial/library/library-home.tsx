import * as React from "react"
import { motion } from "framer-motion"
import { Plus, Search, BookOpen, RotateCcw, Sparkles, Loader2 } from "lucide-react"
import { cn } from "@/lib/utils"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import {
  usePagedMeals,
  useCachedCategories,
  invalidateMealsCache,
} from "@/app-editorial/library/use-paged-meals"
import { MealCatalogCard } from "@/app-editorial/library/meal-catalog-card"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"
import { AiMealLookupDialog } from "@/app-editorial/ai/ai-meal-lookup-dialog"
import { createCatalogMeal, type CreateCatalogMealInput } from "@/lib/api"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function LoadingGrid() {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
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

export function LibraryHome() {
  const [search, setSearch] = React.useState("")
  const [activeCategory, setActiveCategory] = React.useState<string | null>(null)

  const { categories } = useCachedCategories()
  const { meals, count, loading, loadingMore, error, hasMore, loadMore, refresh } =
    usePagedMeals({ category: activeCategory ?? undefined, search })

  // Create runs the catalog insert, then invalidates the shared cache so every
  // filter re-fetches fresh, and refreshes this list.
  const createMeal = React.useCallback(async (input: CreateCatalogMealInput) => {
    const meal = await createCatalogMeal(input)
    invalidateMealsCache()
    refresh()
    return meal
  }, [refresh])

  const onChanged = React.useCallback(() => {
    invalidateMealsCache()
    refresh()
  }, [refresh])

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      {/* Masthead */}
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Nutrition · Library
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            Meal library
          </h1>
          <p className="mt-1.5 max-w-md text-sm text-muted-foreground">
            Browse the shared catalog, add your own meals, and drop any of them straight
            into today's log.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <AiMealLookupDialog
            trigger={
              <Button variant="outline" size="lg">
                <Sparkles className="size-4" /> AI lookup
              </Button>
            }
          />
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
        </div>
      </motion.header>

      {/* Controls */}
      <motion.section {...fade(0.05)} className="flex flex-col gap-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search meals…"
            className="h-9 pl-8"
          />
        </div>

        <div className="flex flex-wrap gap-1.5">
          <button
            type="button"
            onClick={() => setActiveCategory(null)}
            className={cn(
              "rounded-full border px-3 py-1 font-mono text-xs uppercase tracking-wide transition-colors",
              activeCategory === null
                ? "border-transparent bg-[var(--accent-tint)] text-[var(--accent-ink)]"
                : "border-border text-muted-foreground hover:text-foreground"
            )}
          >
            All
          </button>
          {categories.map((cat) => (
            <button
              key={cat.id}
              type="button"
              onClick={() => setActiveCategory(cat.slug)}
              className={cn(
                "rounded-full border px-3 py-1 font-mono text-xs uppercase tracking-wide transition-colors",
                activeCategory === cat.slug
                  ? "border-transparent bg-[var(--accent-tint)] text-[var(--accent-ink)]"
                  : "border-border text-muted-foreground hover:text-foreground"
              )}
            >
              {cat.name}
            </button>
          ))}
        </div>
      </motion.section>

      {/* Content */}
      <motion.section {...fade(0.1)} className="flex flex-col gap-6">
        {error ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <BookOpen className="size-5" />
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
              <Plus className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">No meals match.</div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Try a different search or category — or add one to the catalog.
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
          <>
            <div className="flex items-baseline gap-2 border-b border-border pb-2">
              <h2 className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-muted-foreground">
                Meals
              </h2>
              <span className="font-mono text-xs text-muted-foreground">{count}</span>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {meals.map((meal, i) => (
                <MealCatalogCard
                  key={meal.id}
                  meal={meal}
                  onChanged={onChanged}
                  delay={Math.min(i, 6) * 0.03}
                />
              ))}
            </div>

            {hasMore && (
              <div className="flex justify-center">
                <Button
                  variant="outline"
                  onClick={() => loadMore()}
                  disabled={loadingMore}
                >
                  {loadingMore && <Loader2 className="size-4 animate-spin" />}
                  Show more ({meals.length} of {count})
                </Button>
              </div>
            )}
          </>
        )}
      </motion.section>
    </div>
  )
}

export default LibraryHome
