import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { lookupMeals, getInsights } from "../controllers/ai.controller.js"

export const aiRouter = Router()

aiRouter.post("/ai/meals/lookup", requireAuth, asyncHandler(lookupMeals))
aiRouter.get("/ai/insights", requireAuth, asyncHandler(getInsights))
