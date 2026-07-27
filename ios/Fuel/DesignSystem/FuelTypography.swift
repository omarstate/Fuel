import SwiftUI
import UIKit
import CoreText

// Fuel's type system — a direct mirror of the web app's identity
// (frontend/src/index.css). The web uses exactly three families, and so do we:
//
//   --font-heading / --font-sans → "Google Sans Flex 18pt"  (variable wght 1–1000)
//   --font-mono                  → "JetBrains Mono"          (variable wght 100–800)
//   Arabic swaps heading/sans    → "Cairo"                   (variable wght 200–1000)
//
// There is NO serif anywhere in the web identity — mastheads, the "Fuel"
// wordmark and section titles are all Google Sans Flex. Every numeral, kcal
// value, macro P/C/F label, stat readout and uppercase tracking eyebrow is
// JetBrains Mono (JetBrains Mono is inherently monospaced, so it replaces the
// old `.monospacedDigit()` styling wherever tabular numbers were wanted).
//
// Weight handling: `Font.custom(...).weight(...)` does NOT reliably drive a
// variable font's `wght` axis on iOS, so we set the axis coordinate directly on
// a `UIFontDescriptor` (see `FuelFontFamily.uiFont`). That is what makes bold
// actually render bold. Sizes are scaled through `UIFontMetrics` so Dynamic Type
// still works.

// The OpenType `wght` variation axis identifier (four-char code 'wght').
private let wghtAxisID = 0x77676874 // 2003265652

enum FuelFontFamily {
  // Family names as registered from the bundled variable TTFs (Info.plist
  // UIAppFonts). These must match exactly or `UIFont(descriptor:)` silently
  // falls back to San Francisco.
  static let sans = "Google Sans Flex 18pt"
  static let mono = "JetBrains Mono"
  static let arabic = "Cairo"

  static var isArabic: Bool {
    Locale.current.language.languageCode?.identifier == "ar"
  }

  /// Heading/body face for the current app language: Cairo in Arabic, Google
  /// Sans Flex otherwise. Resolved at call time — changing app language relaunches.
  static var display: String { isArabic ? arabic : sans }

  /// A `UIFont` on a variable family at an explicit `wght` coordinate. Used both
  /// by the SwiftUI helpers below and by UIKit chrome appearance (nav/tab bars).
  static func uiFont(family: String, size: CGFloat, weight: CGFloat) -> UIFont {
    let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
    let descriptor = UIFontDescriptor(fontAttributes: [
      .family: family,
      variationKey: [wghtAxisID: weight],
    ])
    return UIFont(descriptor: descriptor, size: size)
  }
}

// MARK: - Style → size / metric mapping

// Point sizes for each Dynamic Type style at the default content size. Used by
// the style-keyed convenience overloads so callers can migrate `.subheadline`
// etc. one-to-one while keeping a sensible size + scaling anchor.
private func fuelDefaultSize(_ style: Font.TextStyle) -> CGFloat {
  switch style {
  case .largeTitle: return 34
  case .title: return 28
  case .title2: return 22
  case .title3: return 20
  case .headline: return 17
  case .body: return 17
  case .callout: return 16
  case .subheadline: return 15
  case .footnote: return 13
  case .caption: return 12
  case .caption2: return 11
  @unknown default: return 17
  }
}

private func fuelUITextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
  switch style {
  case .largeTitle: return .largeTitle
  case .title: return .title1
  case .title2: return .title2
  case .title3: return .title3
  case .headline: return .headline
  case .body: return .body
  case .callout: return .callout
  case .subheadline: return .subheadline
  case .footnote: return .footnote
  case .caption: return .caption1
  case .caption2: return .caption2
  @unknown default: return .body
  }
}

private func fuelVariableFont(family: String, size: CGFloat, weight: CGFloat, relativeTo textStyle: UIFont.TextStyle) -> Font {
  let scaled = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: size)
  return Font(FuelFontFamily.uiFont(family: family, size: scaled, weight: weight))
}

// MARK: - Semantic API

extension Font {
  // Google Sans Flex (Cairo in Arabic) — headings and body. `weight` drives the
  // variable wght axis directly (400 regular, 500 medium, 600 semibold, 700 bold).
  static func fuelHeading(_ size: CGFloat, weight: CGFloat = 600, relativeTo textStyle: Font.TextStyle = .body) -> Font {
    fuelVariableFont(family: FuelFontFamily.display, size: size, weight: weight, relativeTo: fuelUITextStyle(textStyle))
  }

  static func fuelHeading(_ style: Font.TextStyle, weight: CGFloat = 600) -> Font {
    fuelVariableFont(family: FuelFontFamily.display, size: fuelDefaultSize(style), weight: weight, relativeTo: fuelUITextStyle(style))
  }

  static func fuelBody(_ size: CGFloat, weight: CGFloat = 400, relativeTo textStyle: Font.TextStyle = .body) -> Font {
    fuelVariableFont(family: FuelFontFamily.display, size: size, weight: weight, relativeTo: fuelUITextStyle(textStyle))
  }

  static func fuelBody(_ style: Font.TextStyle, weight: CGFloat = 400) -> Font {
    fuelVariableFont(family: FuelFontFamily.display, size: fuelDefaultSize(style), weight: weight, relativeTo: fuelUITextStyle(style))
  }

  // JetBrains Mono — all numerals, kcal, macro labels, stat readouts, eyebrows.
  static func fuelMono(_ size: CGFloat, weight: CGFloat = 500, relativeTo textStyle: Font.TextStyle = .body) -> Font {
    fuelVariableFont(family: FuelFontFamily.mono, size: size, weight: weight, relativeTo: fuelUITextStyle(textStyle))
  }

  static func fuelMono(_ style: Font.TextStyle, weight: CGFloat = 500) -> Font {
    fuelVariableFont(family: FuelFontFamily.mono, size: fuelDefaultSize(style), weight: weight, relativeTo: fuelUITextStyle(style))
  }

  // MARK: Named roles (mirror the web's masthead / section / stat hierarchy)

  /// Large display for date mastheads and screen headlines (~34, bold).
  static var fuelMasthead: Font { fuelHeading(34, weight: 700, relativeTo: .largeTitle) }

  /// Screen / sheet headline (~27, semibold).
  static var fuelTitle: Font { fuelHeading(27, weight: 600, relativeTo: .title) }

  /// Section / card headline (~22, semibold).
  static var fuelTitle2: Font { fuelHeading(22, weight: 600, relativeTo: .title2) }

  /// Big numeric readout — remaining kcal in the calorie ring (mono, ~34).
  static var fuelStatNumber: Font { fuelMono(34, weight: 600, relativeTo: .largeTitle) }

  /// Medium numeric readout for stat tiles / target rings (mono, ~22).
  static var fuelMetric: Font { fuelMono(22, weight: 600, relativeTo: .title2) }
}

// MARK: - Eyebrow

// The uppercase, letter-spaced eyebrow label used above section titles and on
// stat tiles / kcal readouts. Mono, small, ~0.14em tracking — matching the web's
// `font-mono uppercase tracking-[0.14em]` eyebrows. Tracking is applied at the
// Text/View level (SwiftUI can't fold it into a `Font`), so it lives here.
struct EyebrowStyle: ViewModifier {
  var size: CGFloat = 11
  var color: Color = .fuelSubtle

  func body(content: Content) -> some View {
    content
      .font(.fuelMono(size, weight: 500, relativeTo: .caption2))
      .textCase(.uppercase)
      .tracking(size * 0.14)
      .foregroundStyle(color)
  }
}

extension View {
  func fuelEyebrow(size: CGFloat = 11, color: Color = .fuelSubtle) -> some View {
    modifier(EyebrowStyle(size: size, color: color))
  }
}
