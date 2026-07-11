import { supabase } from "../config/supabase.js"
import {
  rowToCatalogMeal,
  toCatalogMealDetail,
  dtoToRow,
  dtoToUpdateRow,
} from "../models/catalog-meal.model.js"
import { rowToCategory } from "../models/category.model.js"
import { ApiError } from "../utils/api-error.js"
import { isAdmin } from "../utils/is-admin.js"

const SELECT_WITH_CATEGORY = "*, meal_categories(id, name, slug)"
const DEFAULT_LIMIT = 100

export const listMeals = async ({ category, search, limit, offset } = {}) => {
  const useInnerJoin = Boolean(category)
  let query = supabase
    .from("catalog_meals")
    .select(useInnerJoin ? "*, meal_categories!inner(id, name, slug)" : SELECT_WITH_CATEGORY, {
      count: "exact",
    })
    .order("created_at", { ascending: false })

  if (category) {
    query = query.eq("meal_categories.slug", category)
  }

  if (search) {
    query = query.ilike("name", `%${search}%`)
  }

  const safeLimit = limit && limit > 0 ? limit : DEFAULT_LIMIT
  const safeOffset = offset && offset > 0 ? offset : 0
  query = query.range(safeOffset, safeOffset + safeLimit - 1)

  const { data, error, count } = await query

  if (error) throw ApiError.badRequest("Failed to load meals", error.message)

  return { data: data.map(rowToCatalogMeal), count: count ?? data.length }
}

export const listMealsGrouped = async () => {
  const { data: categoryRows, error: categoryError } = await supabase
    .from("meal_categories")
    .select("*")
    .order("sort_order", { ascending: true })

  if (categoryError) throw ApiError.badRequest("Failed to load categories", categoryError.message)

  const { data: mealRows, error: mealError } = await supabase
    .from("catalog_meals")
    .select(SELECT_WITH_CATEGORY)
    .order("created_at", { ascending: false })

  if (mealError) throw ApiError.badRequest("Failed to load meals", mealError.message)

  const meals = mealRows.map(rowToCatalogMeal)

  return categoryRows.map((categoryRow) => {
    const category = rowToCategory(categoryRow)
    return {
      category,
      meals: meals.filter((meal) => meal.category?.id === category.id),
    }
  })
}

const SYSTEM_CREATOR = { name: "Fuel Team", system: true }
const UNKNOWN_CREATOR = { name: "A Fuel member", system: false }

const getCreatorInfo = async (createdBy) => {
  if (!createdBy) return SYSTEM_CREATOR

  try {
    const { data, error } = await supabase.auth.admin.getUserById(createdBy)
    if (error || !data?.user?.email) return UNKNOWN_CREATOR

    const [localPart] = data.user.email.split("@")
    return { name: localPart || UNKNOWN_CREATOR.name, system: false }
  } catch {
    return UNKNOWN_CREATOR
  }
}

const getMealStats = async (catalogMealId) => {
  const { data, error } = await supabase
    .from("meals")
    .select("user_id, logged_at")
    .eq("catalog_meal_id", catalogMealId)

  if (error) throw ApiError.badRequest("Failed to load meal stats", error.message)

  const rows = data ?? []
  const now = new Date()
  const startOfUTCDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))

  const loggedTotal = rows.length
  const loggedToday = rows.filter((row) => new Date(row.logged_at) >= startOfUTCDay).length
  const uniqueLoggers = new Set(rows.map((row) => row.user_id)).size
  const lastLoggedAt = rows.reduce((latest, row) => {
    if (!row.logged_at) return latest
    if (!latest || new Date(row.logged_at) > new Date(latest)) return row.logged_at
    return latest
  }, null)

  return { loggedToday, loggedTotal, uniqueLoggers, lastLoggedAt }
}

export const getMealById = async (id) => {
  const { data, error } = await supabase
    .from("catalog_meals")
    .select(SELECT_WITH_CATEGORY)
    .eq("id", id)
    .maybeSingle()

  if (error) throw ApiError.badRequest("Failed to load meal", error.message)
  if (!data) throw ApiError.notFound("Meal not found")

  const [creator, stats] = await Promise.all([getCreatorInfo(data.created_by), getMealStats(id)])

  return toCatalogMealDetail(rowToCatalogMeal(data), { creator, stats })
}

export const listMyMeals = async (userId) => {
  const { data, error } = await supabase
    .from("catalog_meals")
    .select(SELECT_WITH_CATEGORY)
    .eq("created_by", userId)
    .order("created_at", { ascending: false })

  if (error) throw ApiError.badRequest("Failed to load your meals", error.message)

  return data.map(rowToCatalogMeal)
}

export const createMeal = async (dto, userId) => {
  const { data, error } = await supabase
    .from("catalog_meals")
    .insert({ ...dtoToRow(dto), created_by: userId })
    .select(SELECT_WITH_CATEGORY)
    .single()

  if (error) throw ApiError.badRequest("Failed to create meal", error.message)

  return rowToCatalogMeal(data)
}

const loadMealOrThrow = async (id) => {
  const { data, error } = await supabase
    .from("catalog_meals")
    .select("id, created_by")
    .eq("id", id)
    .maybeSingle()

  if (error) throw ApiError.badRequest("Failed to load meal", error.message)
  if (!data) throw ApiError.notFound("Meal not found")

  return data
}

// Only the meal's creator or an admin (ADMIN_EMAILS) may edit/delete it.
const assertCanModify = (meal, user, action) => {
  if (meal.created_by === user.id || isAdmin(user)) return
  throw ApiError.forbidden(`You can only ${action} meals you created.`)
}

export const updateMeal = async (id, dto, user) => {
  const meal = await loadMealOrThrow(id)
  assertCanModify(meal, user, "edit")

  const { data, error } = await supabase
    .from("catalog_meals")
    .update(dtoToUpdateRow(dto))
    .eq("id", id)
    .select(SELECT_WITH_CATEGORY)
    .single()

  if (error) throw ApiError.badRequest("Failed to update meal", error.message)

  return rowToCatalogMeal(data)
}

export const deleteMeal = async (id, user) => {
  const meal = await loadMealOrThrow(id)
  assertCanModify(meal, user, "delete")

  const { error } = await supabase.from("catalog_meals").delete().eq("id", id)

  if (error) throw ApiError.badRequest("Failed to delete meal", error.message)

  return { id }
}
