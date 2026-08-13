import { supabase } from "../config/supabase.js"
import { rowToProfile, dtoToRow } from "../models/profile.model.js"
import { computeTargets } from "../utils/compute-targets.js"
import { ApiError } from "../utils/api-error.js"

export const getProfile = async (userId) => {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle()

  if (error) throw ApiError.badRequest("Failed to load profile", error.message)
  if (!data) return null

  return rowToProfile(data)
}

// Manual target override: writes the four target columns directly (they are
// normally server-computed). The next PUT /profile (details edit) recomputes
// and overwrites these — that contract is surfaced in the clients' UI copy.
export const updateTargets = async (userId, dto) => {
  const { data, error } = await supabase
    .from("profiles")
    .update({
      target_calories: dto.calories,
      target_protein: dto.protein,
      target_carbs: dto.carbs,
      target_fat: dto.fat,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId)
    .select("*")
    .maybeSingle()

  if (error) throw ApiError.badRequest("Failed to save targets", error.message)
  if (!data) throw ApiError.notFound("Profile not found — complete onboarding first")

  return rowToProfile(data)
}

export const upsertProfile = async (userId, dto) => {
  const targets = computeTargets(dto)

  const { data, error } = await supabase
    .from("profiles")
    .upsert({ ...dtoToRow(dto, targets), user_id: userId }, { onConflict: "user_id" })
    .select("*")
    .single()

  if (error) throw ApiError.badRequest("Failed to save profile", error.message)

  return rowToProfile(data)
}
