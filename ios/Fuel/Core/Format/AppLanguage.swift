import Foundation

// The lang code the AI endpoints expect: "ar" only when the device is set to
// Arabic, otherwise "en". Mirrors the web's `lang` derivation so the Egypt-first
// prompts and localized reason strings match the running locale.
enum AppLanguage {
  static var current: String {
    Locale.current.language.languageCode?.identifier == "ar" ? "ar" : "en"
  }
}
