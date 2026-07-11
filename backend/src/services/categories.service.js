import { supabase } from "../config/supabase.js"
import { rowToCategory } from "../models/category.model.js"
import { ApiError } from "../utils/api-error.js"

export const listCategories = async () => {
  const { data, error } = await supabase
    .from("meal_categories")
    .select("*")
    .order("sort_order", { ascending: true })

  if (error) throw ApiError.badRequest("Failed to load categories", error.message)

  return data.map(rowToCategory)
}
