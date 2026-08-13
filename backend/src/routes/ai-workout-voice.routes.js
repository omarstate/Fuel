import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { requireAuth } from "../middleware/require-auth.js"
import { parseVoiceSetLog, commitVoiceSetLog } from "../controllers/ai-workout-voice.controller.js"

export const aiWorkoutVoiceRouter = Router()

aiWorkoutVoiceRouter.post("/ai/workouts/voice-log", requireAuth, asyncHandler(parseVoiceSetLog))
aiWorkoutVoiceRouter.post("/ai/workouts/voice-log/commit", requireAuth, asyncHandler(commitVoiceSetLog))
