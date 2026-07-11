export class ApiError extends Error {
  constructor(statusCode, message, details) {
    super(message)
    this.name = "ApiError"
    this.statusCode = statusCode
    this.details = details
  }

  static badRequest(message, details) {
    return new ApiError(400, message, details)
  }

  static unauthorized(message = "Authentication required.") {
    return new ApiError(401, message)
  }

  static forbidden(message = "Forbidden") {
    return new ApiError(403, message)
  }

  static notFound(message = "Not found") {
    return new ApiError(404, message)
  }

  static serviceUnavailable(message) {
    return new ApiError(503, message)
  }
}
