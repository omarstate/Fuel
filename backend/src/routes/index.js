import { Router } from "express"
import { healthRouter } from "./health.routes.js"
import { waitlistRouter } from "./waitlist.routes.js"
import { categoriesRouter } from "./categories.routes.js"
import { mealsRouter } from "./meals.routes.js"
import { workoutCategoriesRouter } from "./workout-categories.routes.js"
import { workoutsRouter } from "./workouts.routes.js"
import { meRouter } from "./me.routes.js"
import { profileRouter } from "./profile.routes.js"
import { aiRouter } from "./ai.routes.js"
import { aiVoiceRouter } from "./ai-voice.routes.js"
import { aiWorkoutVoiceRouter } from "./ai-workout-voice.routes.js"

// Mounted at /api by app.js
export const apiRouter = Router()

apiRouter.use(healthRouter)
apiRouter.use(waitlistRouter)
apiRouter.use(categoriesRouter)
apiRouter.use(mealsRouter)
apiRouter.use(workoutCategoriesRouter)
apiRouter.use(workoutsRouter)
apiRouter.use(meRouter)
apiRouter.use(profileRouter)
apiRouter.use(aiRouter)
apiRouter.use(aiVoiceRouter)
apiRouter.use(aiWorkoutVoiceRouter)
