import { supabase } from "../config/supabase.js"
import { ApiError } from "../utils/api-error.js"
import { assertSupabaseConfigured } from "../utils/assert-supabase-configured.js"
import { asyncHandler } from "./async-handler.js"

// Verifies the `Authorization: Bearer <token>` header against Supabase and
// attaches `req.user = { id, email }` on success. Never logs the token.
export const requireAuth = asyncHandler(async (req, _res, next) => {
  assertSupabaseConfigured()

  const authHeader = req.headers.authorization ?? ""
  const [scheme, token] = authHeader.split(" ")

  if (scheme !== "Bearer" || !token) {
    throw ApiError.unauthorized("Authentication required.")
  }

  const { data, error } = await supabase.auth.getUser(token)

  if (error || !data?.user) {
    throw ApiError.unauthorized("Authentication required.")
  }

  req.user = { id: data.user.id, email: data.user.email }
  next()
})
