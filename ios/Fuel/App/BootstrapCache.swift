import Foundation

// Last-known `/me` + `/profile` for the signed-in user, so a returning user
// reaches the app even when the Express backend is unreachable (Render cold
// start, Debug build off the home Wi-Fi). Everything the app does from there
// that is Supabase-direct keeps working; backend-backed features surface their
// own retry banners on use.
//
// Keyed by user id so an account switch on the same device never shows the
// previous account's targets. Cleared on sign-out.
enum BootstrapCache {
  private static let userIdKey = "fuel.bootstrap.userId"
  private static let meKey = "fuel.bootstrap.me"
  private static let profileKey = "fuel.bootstrap.profile"

  struct Entry {
    let me: Me
    let profile: Profile?
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func save(me: Me, profile: Profile?) {
    let defaults = UserDefaults.standard
    guard let meData = try? encoder.encode(me) else { return }
    defaults.set(me.id.lowercased(), forKey: userIdKey)
    defaults.set(meData, forKey: meKey)
    if let profile, let profileData = try? encoder.encode(profile) {
      defaults.set(profileData, forKey: profileKey)
    } else {
      defaults.removeObject(forKey: profileKey)
    }
  }

  /// Refresh only the profile half (onboarding / profile save) without
  /// touching the cached `/me`.
  static func save(profile: Profile) {
    guard UserDefaults.standard.string(forKey: userIdKey) == profile.userId.lowercased(),
          let data = try? encoder.encode(profile) else { return }
    UserDefaults.standard.set(data, forKey: profileKey)
  }

  static func load(for userId: String) -> Entry? {
    let defaults = UserDefaults.standard
    guard defaults.string(forKey: userIdKey) == userId.lowercased(),
          let meData = defaults.data(forKey: meKey),
          let me = try? decoder.decode(Me.self, from: meData) else { return nil }
    let profile = defaults.data(forKey: profileKey).flatMap { try? decoder.decode(Profile.self, from: $0) }
    return Entry(me: me, profile: profile)
  }

  static func clear() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: userIdKey)
    defaults.removeObject(forKey: meKey)
    defaults.removeObject(forKey: profileKey)
  }
}
