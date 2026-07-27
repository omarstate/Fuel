import Foundation

// Errors surfaced by APIClient. Decodes the backend's `{ error: { message } }`
// envelope and maps transport failures to friendly, user-presentable copy.
enum APIError: Error, LocalizedError, Equatable {
  case server(message: String, status: Int)
  case unauthorized
  case timeout
  case network
  case decoding

  var errorDescription: String? {
    switch self {
    case let .server(message, _):
      return message
    case .unauthorized:
      return String(localized: "Your session expired. Please sign in again.")
    case .timeout:
      return String(localized: "The server is taking a while to respond. It may be waking up — try again.")
    case .network:
      return String(localized: "Couldn't reach the server. Check your connection and try again.")
    case .decoding:
      return String(localized: "Something went wrong reading the server's response.")
    }
  }

  // Whether a cold-start retry banner makes sense.
  var isTimeout: Bool {
    if case .timeout = self { return true }
    return false
  }

  // The backend error envelope shape.
  struct Envelope: Decodable {
    struct Inner: Decodable { let message: String }
    let error: Inner
  }

  // Build an APIError from an HTTP status + response body.
  static func from(status: Int, data: Data) -> APIError {
    if status == 401 { return .unauthorized }
    let message = (try? JSONDecoder().decode(Envelope.self, from: data))?.error.message
    return .server(
      message: message ?? String(localized: "Request failed (\(status))."),
      status: status
    )
  }
}
