import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { parseVoiceLog, commitVoiceLog } from "../controllers/ai-voice.controller.js"

export const aiVoiceRouter = Router()

aiVoiceRouter.post("/ai/meals/voice-log", requireAuth, asyncHandler(parseVoiceLog))
aiVoiceRouter.post("/ai/meals/voice-log/commit", requireAuth, asyncHandler(commitVoiceLog))
