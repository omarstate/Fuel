import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { joinWaitlist, getWaitlistCount } from "../controllers/waitlist.controller.js"

export const waitlistRouter = Router()

waitlistRouter.post("/waitlist", asyncHandler(joinWaitlist))
waitlistRouter.get("/waitlist/count", asyncHandler(getWaitlistCount))
