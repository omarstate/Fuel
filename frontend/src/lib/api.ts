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
