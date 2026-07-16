import { isAdmin } from "../utils/is-admin.js"
import { supabase } from "../config/supabase.js"
import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { ApiError } from "../utils/api-error.js"

export const getMe = async (req, res) => {
  res.json({
    data: {
      id: req.user.id,
      email: req.user.email,
      isAdmin: isAdmin(req.user),
    },
  })
}

// Permanently delete the signed-in user's account. Profiles, meals and
// workout sessions all FK to auth.users with `on delete cascade`, so removing
// the auth user removes every trace of their data in one shot.
export const deleteMe = async (req, res) => {
  assertSupabaseConfigured()

  const { error } = await supabase.auth.admin.deleteUser(req.user.id)
  if (error) throw ApiError.badRequest("Failed to delete account", error.message)

  res.json({ data: { deleted: true } })
}
