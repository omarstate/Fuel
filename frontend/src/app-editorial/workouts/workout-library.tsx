import * as React from "react"
import { motion } from "framer-motion"
import { Plus, Search, ListChecks, RotateCcw } from "lucide-react"
import { cn } from "@/lib/utils"
import { Input } from "@/components/ui/input"
import { useWorkouts } from "@/app-editorial/workouts/use-workouts"
import { WorkoutCard } from "@/app-editorial/workouts/workout-card"
import { AddWorkoutDialog } from "@/app-editorial/workouts/add-workout-dialog"
import type { Workout } from "@/lib/api"

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

export function WorkoutLibrary() {
  const { grouped, categories, loading, error, refresh, createWorkout } = useWorkouts()
  const [search, setSearch] = React.useState("")
  const [activeCategory, setActiveCategory] = React.useState<string | null>(null)

  const allWorkouts = React.useMemo<Workout[]>(
    () => grouped.flatMap((g) => g.workouts),
    [grouped]
  )
  // Dedupe by id: a workout can appear in multiple category groups since it's
  // many-to-many, but the flat "all workouts" view should list it once.
  const uniqueWorkouts = React.useMemo(() => {
    const seen = new Set<string>()
    return allWorkouts.filter((w) => {
      if (seen.has(w.id)) return false
      seen.add(w.id)
      return true
    })
  }, [allWorkouts])

  const filtering = search.trim().length > 0 || activeCategory !== null

  const filteredWorkouts = React.useMemo(() => {
    const q = search.trim().toLowerCase()
    return uniqueWorkouts.filter((workout) => {
      const matchesSearch = q ? workout.name.toLowerCase().includes(q) : true
      const matchesCategory = activeCategory
        ? workout.categories.some((c) => c.slug === activeCategory)
        : true
      return matchesSearch && matchesCategory
    })
  }, [uniqueWorkouts, search, activeCategory])

  const totalCount = uniqueWorkouts.length

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      {/* Masthead */}
      <motion.header
        {...fade()}
        className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6"
      >
        <div>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            Workouts · Library
          </div>
          <h1 className="mt-2 font-heading text-4xl font-semibold tracking-tight text-foreground">
            Workout library
          </h1>
          <p className="mt-1.5 max-w-md text-sm text-muted-foreground">
            Browse the shared catalog and add your own workouts, tagged with every type
            they belong to.
          </p>
        </div>
        <AddWorkoutDialog
          onCreate={createWorkout}
          trigger={
            <button
              type="button"
              className="inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
            >
              <Plus className="size-4" /> Add workout
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
            placeholder="Search workouts…"
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
              <ListChecks className="size-5" />
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
              <div className="font-medium text-foreground">No workouts yet</div>
              <p className="mt-1 max-w-xs text-sm text-muted-foreground">
                Add the first one to start building the shared catalog.
              </p>
            </div>
            <AddWorkoutDialog
              onCreate={createWorkout}
              trigger={
                <button
                  type="button"
                  className="mt-1 inline-flex items-center gap-2 rounded-lg bg-[#14120f] px-4 py-2 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d]"
                >
                  <Plus className="size-4" /> Add the first workout
                </button>
              }
            />
          </div>
        ) : filtering ? (
          filteredWorkouts.length === 0 ? (
            <div className="rounded-xl border border-border bg-card px-6 py-14 text-center text-sm text-muted-foreground">
              No workouts match your search.
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {filteredWorkouts.map((workout, i) => (
                <WorkoutCard key={workout.id} workout={workout} delay={Math.min(i, 6) * 0.03} />
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
                  {group.workouts.length}
                </span>
              </div>
              {group.workouts.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  No workouts in this category yet.
                </p>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {group.workouts.map((workout, i) => (
                    <WorkoutCard
                      key={workout.id}
                      workout={workout}
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

export default WorkoutLibrary
