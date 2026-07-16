import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { getMe, deleteMe } from "../controllers/me.controller.js"

export const meRouter = Router()

meRouter.get("/me", requireAuth, asyncHandler(getMe))
meRouter.delete("/me", requireAuth, asyncHandler(deleteMe))
