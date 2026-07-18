import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { lookupMeals, getInsights, suggestMeals } from "../controllers/ai.controller.js"

export const aiRouter = Router()

aiRouter.post("/ai/meals/lookup", requireAuth, asyncHandler(lookupMeals))
aiRouter.post("/ai/meals/suggest", requireAuth, asyncHandler(suggestMeals))
aiRouter.get("/ai/insights", requireAuth, asyncHandler(getInsights))
