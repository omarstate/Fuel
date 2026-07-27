import Foundation
import Supabase

// Singleton wrapping the Supabase client. Exposes auth helpers and a fresh
// access-token accessor. NOTE: email confirmation is ON in this project, so
// signUp may return a user with no session — surface a "check your email" state.
final class SupabaseService: Sendable {
  static let shared = SupabaseService()

  let client: SupabaseClient

  private init() {
    self.client = SupabaseClient(
      supabaseURL: AppConfig.supabaseURL,
      supabaseKey: AppConfig.supabaseKey
    )
  }

  var auth: AuthClient { client.auth }

  // Result of a sign-up attempt.
  enum SignUpOutcome: Sendable {
    /// A full session was created (email confirmation disabled) — user is in.
    case signedIn
    /// Only a user record came back — confirmation email pending.
    case confirmationRequired
  }

  func signIn(email: String, password: String) async throws {
    _ = try await auth.signIn(email: email, password: password)
  }

  func signUp(email: String, password: String) async throws -> SignUpOutcome {
    let response = try await auth.signUp(email: email, password: password)
    return response.session == nil ? .confirmationRequired : .signedIn
  }

  func signOut() async throws {
    try await auth.signOut()
  }

  /// The current user's display name from auth metadata, if set (mirrors the
  /// web app's `user_metadata.display_name`).
  var displayName: String? {
    guard let value = auth.currentUser?.userMetadata["display_name"]?.stringValue else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// The current user's email, if a session is loaded.
  var currentEmail: String? { auth.currentUser?.email }

  /// Update the display name in auth metadata (mirrors `updateDisplayName` in
  /// the web `frontend/src/lib/auth.tsx`).
  func updateDisplayName(_ name: String) async throws {
    _ = try await auth.update(user: UserAttributes(data: ["display_name": .string(name)]))
  }

  /// Update the account password. Requires ≥ 6 characters (validated by the
  /// caller). Note: if "secure password change" is enabled on the Supabase
  /// project this would require reauthentication; the default project allows a
  /// direct update for the signed-in user.
  func updatePassword(_ password: String) async throws {
    _ = try await auth.update(user: UserAttributes(password: password))
  }

  /// Returns a valid access token, auto-refreshing if needed. Never cache the
  /// returned JWT — always fetch fresh from the session.
  func accessToken() async throws -> String {
    try await auth.session.accessToken
  }

  /// The current session loaded from storage, if any (may be expired).
  var currentSession: Session? {
    auth.currentSession
  }

  /// Auth state stream driving AppState.
  var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
    auth.authStateChanges
  }
}
