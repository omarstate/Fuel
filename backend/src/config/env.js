// Reads and normalizes environment variables. Never throws at import time —
// missing Supabase credentials should degrade individual routes (503), not
// crash the whole process.

const SUPABASE_URL = process.env.SUPABASE_URL ?? ""
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ""

// Comma-separated allowlist of admin emails, e.g. "a@x.com,b@y.com". Emails
// are lowercased so comparisons against a verified user's email are
// case-insensitive.
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS ?? "")
  .split(",")
  .map((email) => email.trim().toLowerCase())
  .filter(Boolean)

export const env = {
  PORT: Number(process.env.PORT) || 4000,
  CORS_ORIGIN: process.env.CORS_ORIGIN ?? "http://localhost:5173",
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  isSupabaseConfigured: Boolean(SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY),
  adminEmails: ADMIN_EMAILS,
}
