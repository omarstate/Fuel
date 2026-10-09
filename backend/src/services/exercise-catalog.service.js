// Exercise catalog — a local mirror of free-exercise-db (public domain, ~870
// exercises with muscles, equipment, instructions and demo photos) that the
// app's workout library browses, plus the one-tap copy of a browsed exercise
// into the curated `workouts` catalog.
//
// Two tables, two jobs, deliberately kept apart:
//   exercise_catalog  — the raw dataset mirror (migration 0013). Read-only to
//                       clients, rewritten wholesale by the admin import.
//   workouts          — the curated library you actually train from, unchanged
//                       since migration 0003. `addExerciseToWorkouts` is the
//                       only bridge between them.
//
// Every read/write here tolerates migration 0013 NOT having run: Postgres'
// undefined-table error (and PostgREST's schema-cache miss, which is the same
// thing seen through the API) is mapped to a 503 whose message names the
// migration, rather than bubbling up as an opaque 500. This mirrors the
// fail-soft posture in barcode.service.js, but louder on purpose — browsing an
// empty table silently would look like "the dataset has nothing in it".

import { supabase } from "../config/supabase.js"
import { rowToWorkout } from "../models/workout.model.js"
import { rowToExercise } from "../models/exercise.model.js"
import { ApiError } from "../utils/api-error.js"

const TABLE = "exercise_catalog"

const DATASET_URL =
  "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"

// The dataset is ~1MB of JSON from a CDN; generous because a cold Render dyno
// plus a slow upstream should not lose an import that only an admin runs.
const FETCH_TIMEOUT_MS = 60_000

// PostgREST caps a single insert payload long before Postgres does; 200 rows
// per statement keeps each request comfortably small and makes a partial
// failure cheap to reason about (slugs are the conflict target, so a retry of
// the whole import is idempotent).
const CHUNK_SIZE = 200

const DEFAULT_LIMIT = 30
const MAX_LIMIT = 100

// ---------------------------------------------------------------------------
// Missing-table detection
// ---------------------------------------------------------------------------

// Supabase surfaces a missing relation two ways depending on whether PostgREST
// has the table in its schema cache: 42P01 (undefined_table) straight from
// Postgres, or PGRST205 ("Could not find the table ... in the schema cache").
const isMissingTable = (error) => {
  if (!error) return false
  if (error.code === "42P01" || error.code === "PGRST205") return true
  const message = `${error.message ?? ""}`.toLowerCase()
  return message.includes("does not exist") || message.includes("schema cache")
}

const missingTableError = () =>
  ApiError.serviceUnavailable(
    "The exercise catalog table doesn't exist yet. Run supabase/migrations/0013_exercise_catalog.sql in the Supabase SQL editor, then try again."
  )

// ---------------------------------------------------------------------------
// Dataset normalization
// ---------------------------------------------------------------------------

const toNullableString = (value) => {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  return trimmed || null
}

// Lenient on purpose: an upstream release that adds a field, drops `mechanic`
// on a few entries, or ships an exercise with no images must still import. Only
// a usable id + name + category is non-negotiable, and anything short of that
// is skipped rather than failing the whole run.
const toStringArray = (value) =>
  Array.isArray(value)
    ? value.map((entry) => toNullableString(entry)).filter(Boolean)
    : []

const toRow = (entry) => {
  if (!entry || typeof entry !== "object") return null
  const slug = toNullableString(entry.id)
  const name = toNullableString(entry.name)
  const category = toNullableString(entry.category)
  if (!slug || !name || !category) return null

  return {
    slug,
    name,
    category,
    level: toNullableString(entry.level),
    mechanic: toNullableString(entry.mechanic),
    force: toNullableString(entry.force),
    equipment: toNullableString(entry.equipment),
    primary_muscles: toStringArray(entry.primaryMuscles),
    secondary_muscles: toStringArray(entry.secondaryMuscles),
    instructions: toStringArray(entry.instructions),
    images: toStringArray(entry.images),
    source: "free-exercise-db",
    imported_at: new Date().toISOString(),
  }
}

// ---------------------------------------------------------------------------
// Import (admin)
// ---------------------------------------------------------------------------

const fetchDataset = async () => {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
  let res
  try {
    res = await fetch(DATASET_URL, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    })
  } catch {
    throw ApiError.serviceUnavailable(
      "Couldn't reach the exercise dataset on GitHub. Try again shortly."
    )
  } finally {
    clearTimeout(timer)
  }

  if (!res.ok) {
    throw ApiError.serviceUnavailable(
      `The exercise dataset returned an error (status ${res.status}). Try again shortly.`
    )
  }

  let payload
  try {
    payload = await res.json()
  } catch {
    throw ApiError.serviceUnavailable("The exercise dataset sent an unreadable response.")
  }

  if (!Array.isArray(payload) || payload.length === 0) {
    throw ApiError.serviceUnavailable("The exercise dataset came back empty.")
  }

  return payload
}

/**
 * Fetch free-exercise-db and upsert every exercise by slug.
 * Re-running is safe and is how the mirror is refreshed.
 * @returns {Promise<{ imported: number, total: number, skipped: number }>}
 */
export const importExerciseCatalog = async () => {
  const payload = await fetchDataset()

  const rows = payload.map(toRow).filter(Boolean)
  if (rows.length === 0) {
    throw ApiError.serviceUnavailable(
      "The exercise dataset had no usable entries (every row was missing an id, name or category)."
    )
  }

  let imported = 0
  for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
    const chunk = rows.slice(i, i + CHUNK_SIZE)
    const { error } = await supabase.from(TABLE).upsert(chunk, { onConflict: "slug" })
    if (isMissingTable(error)) throw missingTableError()
    if (error) throw ApiError.badRequest("Failed to import the exercise catalog", error.message)
    imported += chunk.length
  }

  return { imported, total: payload.length, skipped: payload.length - rows.length }
}

// ---------------------------------------------------------------------------
// Browse
// ---------------------------------------------------------------------------

// `%` and `_` are ilike wildcards. No dataset name contains either today, but a
// user-supplied search string can, and a stray `%` would silently widen the
// match instead of narrowing it.
const escapeLike = (value) => value.replace(/[\\%_]/g, (match) => `\\${match}`)

// Which of these exercises are already in `workouts`? One extra query per page
// (≤100 names), matched on the exact name the add endpoint inserts, so the
// picker can show "In library" before the user taps rather than after. Entirely
// best-effort: any failure just leaves every row addable.
const markInLibrary = async (rows) => {
  if (rows.length === 0) return rows
  const { data, error } = await supabase
    .from("workouts")
    .select("name")
    .in("name", rows.map((row) => row.name))
  if (error || !Array.isArray(data)) return rows

  const existing = new Set(data.map((row) => `${row.name}`.toLowerCase()))
  return rows.map((row) => ({ ...row, in_library: existing.has(row.name.toLowerCase()) }))
}

/**
 * Paginated browse over the mirrored dataset.
 * @returns {Promise<{ data: object[], count: number }>}
 */
export const listExercises = async ({
  search,
  category,
  muscle,
  equipment,
  limit,
  offset,
} = {}) => {
  const safeLimit = Math.min(limit && limit > 0 ? limit : DEFAULT_LIMIT, MAX_LIMIT)
  const safeOffset = offset && offset > 0 ? offset : 0

  let query = supabase
    .from(TABLE)
    .select("*", { count: "exact" })
    .order("name", { ascending: true })

  if (search) query = query.ilike("name", `%${escapeLike(search)}%`)
  if (category) query = query.eq("category", category)
  if (equipment) query = query.eq("equipment", equipment)
  // text[] containment — "has this muscle among its primaries", not "equals".
  if (muscle) query = query.contains("primary_muscles", [muscle])

  query = query.range(safeOffset, safeOffset + safeLimit - 1)

  const { data, error, count } = await query

  if (isMissingTable(error)) throw missingTableError()
  if (error) throw ApiError.badRequest("Failed to load exercises", error.message)

  const rows = await markInLibrary(data ?? [])

  return { data: rows.map(rowToExercise), count: count ?? rows.length }
}

// ---------------------------------------------------------------------------
// Add to the curated workout catalog
// ---------------------------------------------------------------------------

// The dataset's 17 primary-muscle spellings, mapped onto the workout_categories
// slugs seeded by migration 0003. Exhaustive by design — a muscle with no entry
// falls through to 'full-body', so a new upstream muscle degrades gracefully
// instead of producing an uncategorized workout.
const MUSCLE_CATEGORIES = {
  abdominals: ["core"],
  abductors: ["legs", "lower-body"],
  adductors: ["legs", "lower-body"],
  biceps: ["pull", "upper-body"],
  calves: ["legs", "lower-body"],
  chest: ["push", "upper-body"],
  forearms: ["pull", "upper-body"],
  glutes: ["legs", "lower-body"],
  hamstrings: ["legs", "lower-body"],
  lats: ["pull", "upper-body"],
  "lower back": ["pull", "upper-body"],
  "middle back": ["pull", "upper-body"],
  // Neck work is neither a press nor a pull in this taxonomy — upper body only.
  neck: ["upper-body"],
  quadriceps: ["legs", "lower-body"],
  shoulders: ["push", "upper-body"],
  traps: ["pull", "upper-body"],
  triceps: ["push", "upper-body"],
}

// Cardio entries carry an incidental primary muscle ("quadriceps" on a
// treadmill run) that would file them under Legs and mislead the library, so
// the dataset category wins outright for those.
const categorySlugsFor = (row) => {
  if (row.category === "cardio") return ["full-body"]

  const slugs = new Set()
  for (const muscle of row.primary_muscles ?? []) {
    for (const slug of MUSCLE_CATEGORIES[`${muscle}`.toLowerCase()] ?? []) {
      slugs.add(slug)
    }
  }
  return slugs.size > 0 ? [...slugs] : ["full-body"]
}

// "lower back" -> "Lower Back", "e-z curl bar" -> "E-Z Curl Bar". Capitalizes
// after any non-letter, so hyphenated equipment reads right.
const titleCase = (value) => {
  const text = toNullableString(value)
  if (!text) return null
  return text.replace(/(^|[^\p{L}])(\p{L})/gu, (_match, prefix, letter) => prefix + letter.toUpperCase())
}

const MAX_DESCRIPTION = 240

// The dataset's instructions are a numbered how-to, 3–8 steps long. A catalog
// card shows two lines, so take the first step and — only if there is room —
// the second, then hard-cap at a sentence boundary-ish length.
const descriptionFrom = (instructions) => {
  const steps = (instructions ?? []).map((step) => `${step}`.trim()).filter(Boolean)
  if (steps.length === 0) return null

  let text = steps[0]
  if (steps[1] && text.length < 140) text = `${text} ${steps[1]}`
  if (text.length <= MAX_DESCRIPTION) return text
  return `${text.slice(0, MAX_DESCRIPTION - 1).trimEnd()}…`
}

const getExerciseBySlug = async (slug) => {
  const { data, error } = await supabase.from(TABLE).select("*").eq("slug", slug).maybeSingle()
  if (isMissingTable(error)) throw missingTableError()
  if (error) throw ApiError.badRequest("Failed to load the exercise", error.message)
  if (!data) throw ApiError.notFound("That exercise isn't in the catalog.")
  return data
}

const SELECT_WITH_CATEGORIES = "*, workout_categories(id, name, slug)"

const loadWorkout = async (id) => {
  const { data, error } = await supabase
    .from("workouts")
    .select(SELECT_WITH_CATEGORIES)
    .eq("id", id)
    .single()
  if (error) throw ApiError.badRequest("Failed to load the workout", error.message)
  return rowToWorkout(data)
}

// Case-insensitive name match against the curated catalog. ilike with the
// wildcards escaped is an exact comparison that ignores case — exactly the
// "already added" check we want, and it also catches a workout the user typed
// in by hand before the dataset existed.
const findExistingWorkout = async (name) => {
  const { data, error } = await supabase
    .from("workouts")
    .select(SELECT_WITH_CATEGORIES)
    .ilike("name", escapeLike(name))
    .limit(1)
  if (error) throw ApiError.badRequest("Failed to check the workout catalog", error.message)
  return Array.isArray(data) && data.length > 0 ? rowToWorkout(data[0]) : null
}

/**
 * Copy one catalog exercise into `workouts`, tagged with the workout categories
 * its primary muscles imply. Idempotent: a workout with the same name (any
 * case) is returned untouched with `created: false`.
 * @returns {Promise<{ workout: object, created: boolean }>}
 */
export const addExerciseToWorkouts = async (userId, slug) => {
  const exercise = await getExerciseBySlug(slug)

  const existing = await findExistingWorkout(exercise.name)
  if (existing) return { workout: existing, created: false }

  const { data: workoutRow, error: insertError } = await supabase
    .from("workouts")
    .insert({
      name: exercise.name,
      description: descriptionFrom(exercise.instructions),
      primary_muscle: titleCase((exercise.primary_muscles ?? [])[0]),
      equipment: titleCase(exercise.equipment),
      // The dataset has no prescription — sets/reps stay empty so the card
      // shows no target pill rather than a made-up one.
      target_sets: null,
      target_reps: null,
      created_by: userId,
    })
    .select("id")
    .single()

  if (insertError) {
    // Lost a race with a concurrent add of the same exercise — the other
    // request's row is the right answer.
    const raced = await findExistingWorkout(exercise.name)
    if (raced) return { workout: raced, created: false }
    throw ApiError.badRequest("Failed to add the exercise", insertError.message)
  }

  const slugs = categorySlugsFor(exercise)
  const { data: categoryRows, error: categoryError } = await supabase
    .from("workout_categories")
    .select("id")
    .in("slug", slugs)

  // A workout with no categories is still a usable workout; losing the tags is
  // not worth failing an add the user already saw succeed.
  if (!categoryError && Array.isArray(categoryRows) && categoryRows.length > 0) {
    await supabase.from("workout_category_map").upsert(
      categoryRows.map((row) => ({ workout_id: workoutRow.id, category_id: row.id })),
      { onConflict: "workout_id,category_id" }
    )
  }

  return { workout: await loadWorkout(workoutRow.id), created: true }
}
