import { createClient } from "@supabase/supabase-js"

const url = import.meta.env.VITE_SUPABASE_URL
// New-style publishable key (sb_publishable_…) or the legacy anon JWT.
const anonKey =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ??
  import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured =
  !!url && !!anonKey && !url.includes("YOUR-PROJECT-REF")

if (!isSupabaseConfigured) {
  console.error(
    "[Fuel] Supabase is not configured. Set VITE_SUPABASE_URL and " +
      "VITE_SUPABASE_PUBLISHABLE_KEY in frontend/.env.local, then restart the dev server."
  )
}

export const supabase = createClient(url ?? "", anonKey ?? "", {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})
