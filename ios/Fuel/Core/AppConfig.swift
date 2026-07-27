import Foundation

// Reads build configuration injected via xcconfig -> Info.plist. Traps early
// with a clear message if anything is missing or malformed — a misconfigured
// build should fail loudly at launch, not mysteriously at the first request.
enum AppConfig {
  static let apiBaseURL: URL = url(for: "API_BASE_URL")
  static let supabaseURL: URL = url(for: "SUPABASE_URL")
  static let supabaseKey: String = string(for: "SUPABASE_KEY")

  private static func string(for key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      fatalError(
        "AppConfig: missing or empty Info.plist key \"\(key)\". "
          + "Check Config/*.xcconfig and that Info.plist maps $(\(key))."
      )
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func url(for key: String) -> URL {
    let value = string(for: key)
    guard let url = URL(string: value), url.scheme != nil, url.host != nil else {
      fatalError("AppConfig: value for \"\(key)\" is not a valid URL: \(value)")
    }
    return url
  }
}
