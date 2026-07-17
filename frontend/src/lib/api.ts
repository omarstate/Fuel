// Typed fetch wrapper for the Fuel Express backend (the shared meal catalog).
// Personal-log writes still go straight through supabase-js — see use-meals.ts.

import { supabase } from "@/lib/supabase"
import type { ActivityLevel, Pace, Sex } from "@/lib/nutrition"

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:4000/api"

type ApiEnvelope<T> = { data: T }
type ApiErrorEnvelope = { error: { message: string; details?: unknown } }

export type Category = {
  id: string
  name: string
  slug: string
  description?: string
  sortOrder: number
}

export type CatalogMeal = {
  id: string
  name: string
  description?: string
  servingSize?: string
  calories: number
  protein: number
  carbs: number
  fat: number
  category?: { id: string; name: string; slug: string } | null
  createdAt: string
  createdBy: string | null
  aiSource?: "official" | "estimate" | null
  sourceUrl?: string | null
  macroRanges?: {
    calories: [number, number]
    protein: [number, number]
    carbs: [number, number]
    fat: [number, number]
  } | null
}

export type GroupedCatalog = { category: Category; meals: CatalogMeal[] }[]

export type CatalogMealDetail = CatalogMeal & {
  creator: { name: string; system: boolean }
  stats: {
    loggedToday: number
    loggedTotal: number
    uniqueLoggers: number
    lastLoggedAt: string | null
  }
}

export type WorkoutCategory = {
  id: string
  name: string
  slug: string
  description?: string
  sortOrder: number
}

export type Workout = {
  id: string
  name: string
  description?: string
  primaryMuscle?: string
  equipment?: string
  targetSets?: number
  targetReps?: string
  categories: { id: string; name: string; slug: string }[]
  createdAt: string
}

export type GroupedWorkouts = { category: WorkoutCategory; workouts: Workout[] }[]

/** Runs the fetch/auth/error handling and returns the WHOLE parsed body, so
 * callers that need sibling fields (like a paginated `count`) can read them.
 * `request` wraps this and returns only `.data` for the common case. */
async function requestBody<T = unknown>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    const { data: sessionData } = await supabase.auth.getSession()
    const token = sessionData.session?.access_token

    res = await fetch(`${BASE_URL}${path}`, {
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...init?.headers,
      },
      ...init,
    })
  } catch {
    throw new Error(
      "Couldn't reach the Fuel API. Start the backend with `cd backend && npm run dev`."
    )
  }

  let body: unknown
  try {
    body = await res.json()
  } catch {
    body = null
  }

  if (!res.ok) {
    const message =
      (body as ApiErrorEnvelope | null)?.error?.message ?? res.statusText ?? "Request failed"
    throw new Error(message)
  }

  return body as T
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const body = await requestBody<ApiEnvelope<T>>(path, init)
  return body.data
}

export function getCategories(): Promise<Category[]> {
  return request<Category[]>("/categories")
}

export function getMealsGrouped(): Promise<GroupedCatalog> {
  return request<GroupedCatalog>("/meals/grouped")
}

export function getMeals(params?: { category?: string; search?: string }): Promise<CatalogMeal[]> {
  const query = new URLSearchParams()
  if (params?.category) query.set("category", params.category)
  if (params?.search) query.set("search", params.search)
  const qs = query.toString()
  return request<CatalogMeal[]>(`/meals${qs ? `?${qs}` : ""}`)
}

export type PagedMeals = { meals: CatalogMeal[]; count: number }

/** Paginated catalog fetch — keeps the `count` (exact total) the backend sends
 * alongside `data`, so the caller can drive "Show more" / total-count UI. */
export async function getMealsPaged(params: {
  category?: string
  search?: string
  limit?: number
  offset?: number
}): Promise<PagedMeals> {
  const query = new URLSearchParams()
  if (params.category) query.set("category", params.category)
  if (params.search) query.set("search", params.search)
  if (params.limit != null) query.set("limit", String(params.limit))
  if (params.offset != null) query.set("offset", String(params.offset))
  const qs = query.toString()
  const body = await requestBody<{ data: CatalogMeal[]; count?: number }>(
    `/meals${qs ? `?${qs}` : ""}`
  )
  return { meals: body.data, count: body.count ?? body.data.length }
}

export function getMealDetail(id: string): Promise<CatalogMealDetail> {
  return request<CatalogMealDetail>(`/meals/${id}`)
}

export type CreateCatalogMealInput = {
  name: string
  description?: string
  categoryId: string
  servingSize?: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

export function createCatalogMeal(input: CreateCatalogMealInput): Promise<CatalogMeal> {
  return request<CatalogMeal>("/meals", {
    method: "POST",
    body: JSON.stringify(input),
  })
}

export function updateCatalogMeal(
  id: string,
  input: Partial<CreateCatalogMealInput>
): Promise<CatalogMeal> {
  return request<CatalogMeal>(`/meals/${id}`, {
    method: "PATCH",
    body: JSON.stringify(input),
  })
}

export async function deleteCatalogMeal(id: string): Promise<void> {
  await request<{ id: string }>(`/meals/${id}`, { method: "DELETE" })
}

export function getMe(): Promise<{ id: string; email: string; isAdmin: boolean }> {
  return request("/me")
}

export async function deleteAccount(): Promise<void> {
  await request<{ deleted: boolean }>("/me", { method: "DELETE" })
}

export type Profile = {
  userId: string
  sex: Sex
  age: number
  heightCm: number
  weightKg: number
  goalWeightKg: number
  activityLevel: ActivityLevel
  pace: Pace
  targetCalories: number
  targetProtein: number
  targetCarbs: number
  targetFat: number
  onboardedAt: string
  updatedAt: string
}

export function getProfile(): Promise<Profile | null> {
  return request<Profile | null>("/profile")
}

export type UpsertProfileInput = {
  sex: Sex
  age: number
  heightCm: number
  weightKg: number
  goalWeightKg: number
  activityLevel: ActivityLevel
  pace: Pace
}

export function saveProfile(input: UpsertProfileInput): Promise<Profile> {
  return request<Profile>("/profile", {
    method: "PUT",
    body: JSON.stringify(input),
  })
}

export function getMyMeals(): Promise<CatalogMeal[]> {
  return request<CatalogMeal[]>("/meals/mine")
}

// --- AI meal estimation (Gemini, Egypt-first) ---

export type EstimatedMeal = {
  /** The raw item text the user typed for this estimate. */
  input: string
  /** Whether the AI produced a usable estimate (false → fill in by hand). */
  ok: boolean
  name: string
  servingSize: string
  calories: number
  protein: number
  carbs: number
  fat: number
  /** Which market the numbers came from. */
  source: "egypt" | "regional" | "global" | null
  confidence: "high" | "medium" | "low" | null
  note: string
}

/**
 * Ask the backend to estimate nutrition for a batch of meals. `items` is the
 * user's comma-separated list already split into entries; `place` is where they
 * ate (e.g. "McDonald's"). Returns one estimate per item, in order.
 */
export function estimateMeals(input: {
  place?: string
  items: string[]
}): Promise<EstimatedMeal[]> {
  return request<EstimatedMeal[]>("/meals/estimate", {
    method: "POST",
    body: JSON.stringify(input),
  })
}

export type ExtractedLabel = {
  /** Whether a usable set of values was read (false → retake or fill by hand). */
  ok: boolean
  readable: boolean
  /** Usually null — a facts-panel close-up rarely shows the product name. */
  name: string | null
  /** Which basis the macros are stated on. */
  basis: "per_100g" | "per_serving"
  servingSize: string
  /** Grams (or ml) in one serving, when printed. */
  servingGrams: number | null
  calories: number
  protein: number
  carbs: number
  fat: number
  confidence: "high" | "medium" | "low" | null
  note: string
}

/**
 * Extract nutrition facts from a photo of a product label. `image` is raw
 * base64 (no data-URL prefix); `mimeType` is the encoded type. Values come back
 * on the label's own basis (per 100g or per serving) — the caller scales by
 * portion in the review step before logging.
 */
export function extractMealPhoto(input: {
  image: string
  mimeType: string
}): Promise<ExtractedLabel> {
  return request<ExtractedLabel>("/meals/photo-extract", {
    method: "POST",
    body: JSON.stringify(input),
  })
}

export type BarcodeProduct = {
  /** Whether the barcode exists in the database at all. */
  found: boolean
  /** found AND has usable macros (a found product may lack nutrition data). */
  ok: boolean
  barcode: string
  name: string | null
  brand: string | null
  /** Open Food Facts stores per-100g reliably, so that's the canonical basis. */
  basis: "per_100g" | "per_serving"
  servingSize: string
  servingGrams: number | null
  calories: number
  protein: number
  carbs: number
  fat: number
  confidence: "high" | "medium" | "low" | null
  note: string
}

/** Look up a product by barcode via the backend's Open Food Facts proxy. Never
 * throws for an unknown code — that comes back as `{ found: false }`. */
export function lookupBarcode(code: string): Promise<BarcodeProduct> {
  return request<BarcodeProduct>(`/meals/barcode/${encodeURIComponent(code)}`)
}

export type AiCatalogMealInput = {
  name: string
  description?: string
  servingSize?: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

/**
 * Save reviewed AI meals into the shared catalog under the "AI" category. The
 * backend dedupes by name, so re-saving the same item reuses the existing entry.
 */
export function saveAiMealsToCatalog(meals: AiCatalogMealInput[]): Promise<CatalogMeal[]> {
  return request<CatalogMeal[]>("/meals/ai-catalog", {
    method: "POST",
    body: JSON.stringify({ meals }),
  })
}

export function getWorkoutCategories(): Promise<WorkoutCategory[]> {
  return request<WorkoutCategory[]>("/workout-categories")
}

export function getWorkoutsGrouped(): Promise<GroupedWorkouts> {
  return request<GroupedWorkouts>("/workouts/grouped")
}

export function getWorkouts(params?: { category?: string; search?: string }): Promise<Workout[]> {
  const query = new URLSearchParams()
  if (params?.category) query.set("category", params.category)
  if (params?.search) query.set("search", params.search)
  const qs = query.toString()
  return request<Workout[]>(`/workouts${qs ? `?${qs}` : ""}`)
}

export function createWorkout(input: {
  name: string
  description?: string
  categoryIds: string[]
  primaryMuscle?: string
  equipment?: string
  targetSets?: number
  targetReps?: string
}): Promise<Workout> {
  return request<Workout>("/workouts", {
    method: "POST",
    body: JSON.stringify(input),
  })
}

// --- AI features (Gemini-backed, all via the backend) ---

export type AiLookupItem = { meal: CatalogMeal; created: boolean }

export function aiLookupMeals(
  query: string
): Promise<{ items: AiLookupItem[]; usedAi: boolean }> {
  return request<{ items: AiLookupItem[]; usedAi: boolean }>("/ai/meals/lookup", {
    method: "POST",
    body: JSON.stringify({ query }),
  })
}

export type AiInsights = {
  day: string
  headline: string
  insights: { title: string; body: string }[]
  tips: string[]
  facts?: { streak?: { current: number; best: number } }
  cached?: boolean
}

export function getAiInsights(refresh?: boolean): Promise<AiInsights> {
  return request<AiInsights>(`/ai/insights${refresh ? "?refresh=1" : ""}`)
}
