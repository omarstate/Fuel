import { createApp } from "./src/app.js"
import { env } from "./src/config/env.js"

const app = createApp()

app.listen(env.PORT, () => {
  console.log(`Fuel API listening on http://localhost:${env.PORT}`)
  if (!env.isSupabaseConfigured) {
    console.warn(
      "Supabase is not configured — set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in backend/.env to enable the meal catalog endpoints."
    )
  }
})
