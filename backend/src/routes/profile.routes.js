import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { getProfile, upsertProfile } from "../controllers/profile.controller.js"

export const profileRouter = Router()

profileRouter.get("/profile", requireAuth, asyncHandler(getProfile))
profileRouter.put("/profile", requireAuth, asyncHandler(upsertProfile))
