import express from "express"
import cors from "cors"
import { env } from "./config/env.js"
import { apiRouter } from "./routes/index.js"
import { notFound } from "./middleware/not-found.js"
import { errorHandler } from "./middleware/error-handler.js"

// This is a JSON REST API only — there is intentionally no views/ folder or
// server-rendered templating.
export const createApp = () => {
  const app = express()

  app.use(cors({ origin: env.CORS_ORIGIN }))

  // The photo-extract route carries a base64 image, which blows past the
  // default ~100KB JSON limit. Give just that path a larger ceiling; since
  // express.json() skips a request whose body is already parsed, the global
  // parser below leaves it untouched and every other route keeps the default.
  app.use("/api/meals/photo-extract", express.json({ limit: "12mb" }))
  app.use(express.json())

  app.use("/api", apiRouter)

  app.use(notFound)
  app.use(errorHandler)

  return app
}
