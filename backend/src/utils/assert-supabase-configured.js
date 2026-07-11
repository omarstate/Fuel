import { env } from "../config/env.js"
import { ApiError } from "./api-error.js"

// Guard for any controller that needs the database. Keeps the 503 message
// consistent across every route that touches Supabase.
export const assertSupabaseConfigured = () => {
  if (!env.isSupabaseConfigured) {
    throw ApiError.serviceUnavailable(
      "Supabase is not configured on the server. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in backend/.env."
    )
  }
}
