import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { upsertProfileSchema } from "../validators/profile.validator.js"
import * as profileService from "../services/profile.service.js"

export const getProfile = async (req, res) => {
  assertSupabaseConfigured()
  const data = await profileService.getProfile(req.user.id)
  res.json({ data })
}

export const upsertProfile = async (req, res) => {
  assertSupabaseConfigured()
  const dto = upsertProfileSchema.parse(req.body)
  const data = await profileService.upsertProfile(req.user.id, dto)
  res.json({ data })
}
