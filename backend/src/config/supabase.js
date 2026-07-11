import { createClient } from "@supabase/supabase-js"
import { env } from "./env.js"

// When Supabase isn't configured we still export a client (createClient is
// happy with empty strings) so importers never need a null check on the
// client itself — services should instead guard on `env.isSupabaseConfigured`
// before making a call.
export const supabase = createClient(
  env.SUPABASE_URL || "https://placeholder.invalid",
  env.SUPABASE_SERVICE_ROLE_KEY || "placeholder-key",
  { auth: { persistSession: false } }
)
