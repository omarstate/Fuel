import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import * as categoriesService from "../services/categories.service.js"

export const listCategories = async (_req, res) => {
  assertSupabaseConfigured()
  const data = await categoriesService.listCategories()
  res.json({ data })
}
