import Foundation

// GET /api/me
struct Me: Codable, Equatable, Sendable, Identifiable {
  let id: String
  let email: String
  let isAdmin: Bool
}
