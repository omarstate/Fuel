import { Router } from "express"
import { asyncHandler } from "../middleware/async-handler.js"
import { listCategories } from "../controllers/categories.controller.js"

export const categoriesRouter = Router()

categoriesRouter.get("/categories", asyncHandler(listCategories))
