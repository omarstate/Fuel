import { ZodError } from "zod"
import { ApiError } from "../utils/api-error.js"

// Central error handler — every thrown/forwarded error ends up here and is
// serialized to a consistent { error: { message, details? } } shape.
export const errorHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: {
        message: "Invalid request body",
        details: err.issues,
      },
    })
  }

  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: { message: err.message, ...(err.details ? { details: err.details } : {}) },
    })
  }

  console.error(err)
  res.status(500).json({ error: { message: "Internal server error" } })
}
