import { Router } from "express"

export const healthRouter = Router()

// No DB dependency — must always succeed, even if Supabase isn't configured.
healthRouter.get("/health", (_req, res) => {
  res.json({ ok: true })
})
