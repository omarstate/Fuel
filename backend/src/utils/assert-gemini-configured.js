import { env } from "../config/env.js"
import { ApiError } from "./api-error.js"

// Guard for any controller that needs Gemini. Keeps the 503 message consistent
// across every AI route. Mirrors assert-supabase-configured.js.
export const assertGeminiConfigured = () => {
  if (!env.isGeminiConfigured) {
    throw ApiError.serviceUnavailable(
      "AI features aren't configured. Add GEMINI_API_KEY to backend/.env."
    )
  }
}
