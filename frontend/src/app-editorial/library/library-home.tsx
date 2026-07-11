import * as React from "react"
import { motion } from "framer-motion"
import { Plus, Search, BookOpen, RotateCcw } from "lucide-react"
import { cn } from "@/lib/utils"
import { Input } from "@/components/ui/input"
import { useCatalog } from "@/app-editorial/library/use-catalog"
import { MealCatalogCard } from "@/app-editorial/library/meal-catalog-card"
import { AddCatalogMealDialog } from "@/app-editorial/library/add-catalog-meal-dialog"
import type { CatalogMeal } from "@/lib/api"

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

export function LibraryHome() {
  const { grouped, categories, loading, error, refresh, createMeal, addCatalogMealToLog } =
    useCatalog()
  const [search, setSearch] = React.useState("")
  const [activeCategory, setActiveCategory] = React.useState<string | null>(null)

  const allMeals = React.useMemo<CatalogMeal[]>(
    () => grouped.flatMap((g) => g.meals),
    [grouped]
  )

  const filtering = search.trim().length > 0 || activeCategory !== null

  const filteredMeals = React.useMemo(() => {
    const q = search.trim().toLowerCase()
    return allMeals.filter((meal) => {
      const matchesSearch = q ? meal.name.toLowerCase().includes(q) : true
      const matchesCategory = activeCategory ? meal.category?.slug === activeCategory : true
      return matchesSearch && matchesCategory
    })
  }, [allMeals, search, activeCategory])

  const totalCount = allMeals.length

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
        ) : totalCount === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card px-6 py-14 text-center">
            <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
              <Plus className="size-5" />
            </span>
            <div>
              <div className="font-medium text-foreground">No meals yet</div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Add the first one to start building the shared catalog.
              </p>
            </div>
            <AddCatalogMealDialog
              onCreate={createMeal}
              trigger={
                <button
                  type="button"
                  className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
                >
                  <Plus className="size-4" /> Add the first meal
                </button>
              }
            />
          </div>
        ) : filtering ? (
          filteredMeals.length === 0 ? (
            <div className="rounded-xl border border-border bg-card px-6 py-14 text-center text-sm text-muted-foreground">
              No meals match your search.
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {filteredMeals.map((meal, i) => (
                <MealCatalogCard
                  key={meal.id}
                  meal={meal}
                  onAdd={addCatalogMealToLog}
                  onChanged={refresh}
                  delay={Math.min(i, 6) * 0.03}
                />
              ))}
            </div>
          )
        ) : (
          grouped.map((group) => (
            <div key={group.category.id} className="flex flex-col gap-3">
              <div className="flex items-baseline gap-2 border-b border-border pb-2">
                <h2 className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-muted-foreground">
                  {group.category.name}
                </h2>
                <span className="font-mono text-xs text-muted-foreground">
                  {group.meals.length}
                </span>
              </div>
              {group.meals.length === 0 ? (
                <p className="text-sm text-muted-foreground">No meals in this category yet.</p>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {group.meals.map((meal, i) => (
                    <MealCatalogCard
                      key={meal.id}
                      meal={meal}
                      onAdd={addCatalogMealToLog}
                      delay={Math.min(i, 6) * 0.03}
                    />
                  ))}
                </div>
              )}
            </div>
          ))
        )}
      </motion.section>
    </div>
  )
}

export default LibraryHome
