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

// AI meal estimation (Gemini). The key stays server-side so it never ships in
// the frontend bundle. Model defaults to gemini-2.5-flash, which supports
// Google Search grounding used for looking up real-world nutrition data.
const GEMINI_API_KEY = process.env.GEMINI_API_KEY ?? ""
const GEMINI_MODEL = process.env.GEMINI_MODEL ?? "gemini-2.5-flash"
// Tried when the primary model 429s/errors — free-tier keys rate-limit each
// model separately, so the lite tier's own quota keeps requests flowing. The
// rolling "-latest" alias survives model deprecations (pinned lite model ids
// have already 404'd as "no longer available to new users" on this key).
const GEMINI_FALLBACK_MODEL = process.env.GEMINI_FALLBACK_MODEL ?? "gemini-flash-lite-latest"

export const env = {
  PORT: Number(process.env.PORT) || 4000,
  CORS_ORIGIN: process.env.CORS_ORIGIN ?? "http://localhost:5173",
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  isSupabaseConfigured: Boolean(SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY),
  adminEmails: ADMIN_EMAILS,
  GEMINI_API_KEY,
  GEMINI_MODEL,
  GEMINI_FALLBACK_MODEL,
  isGeminiConfigured: Boolean(GEMINI_API_KEY),
}
