import SwiftUI

// Brand color tokens, backed by color sets in Assets.xcassets (Any + Dark
// variants). Asset symbol generation is enabled, but these explicit
// extensions keep the call-site names stable regardless of Xcode's codegen.
//
// Usage convention (see DESIGN.md):
//   - `fuelVolt` / `fuelCitrus` / `fuelGold` are FILL colors (rings, bars).
//   - `*Ink` variants are for TEXT / icons / thin strokes (volt is unreadable
//     as text on the bone background).
extension Color {
  static let fuelBackground = Color("FuelBackground")
  static let fuelSurface = Color("FuelSurface")
  static let fuelInk = Color("FuelInk")
  static let fuelSubtle = Color("FuelSubtle")
  static let fuelVolt = Color("FuelVolt")
  static let fuelVoltInk = Color("FuelVoltInk")
  /// Calm brand green for LARGE fills on light backgrounds (ring, fat bar,
  /// on-target chart bars). Volt is too loud at that size in light mode — it
  /// stays for small accents and dark surfaces (dark variant of this IS volt).
  static let fuelOlive = Color("FuelOlive")
  /// Over-target signal — warm terracotta (web `#c85a3c`), NOT alarm red.
  /// `fuelDestructive` is reserved for genuinely destructive actions (delete).
  static let fuelOver = Color("FuelOver")
  /// Brand accent green (rings, primary buttons, links, active states). Note:
  /// `fuelCitrus`/`fuelCitrusInk` are historical names — in the dark identity
  /// they ARE the green brand accent (same green as volt/olive), kept so the
  /// many existing accent call-sites re-point without edits.
  static let fuelCitrus = Color("FuelCitrus")
  static let fuelCitrusInk = Color("FuelCitrusInk")
  /// Protein blue — the inner ring, protein macro fill/ink, protein readouts.
  static let fuelBlue = Color("FuelBlue")
  static let fuelBlueInk = Color("FuelBlueInk")
  static let fuelDestructive = Color("FuelDestructive")
  static let fuelGold = Color("FuelGold")
  static let fuelGoldInk = Color("FuelGoldInk")
}

// Macro color convention (matches the web app):
//   protein = citrus, carbs = gold, fat = green (olive fill in light, volt in dark).
enum MacroPalette {
  static let proteinFill = Color.fuelBlue
  static let proteinInk = Color.fuelBlueInk
  static let carbsFill = Color.fuelGold
  static let carbsInk = Color.fuelGoldInk
  static let fatFill = Color.fuelOlive
  static let fatInk = Color.fuelVoltInk
  static let caloriesFill = Color.fuelOlive
  static let caloriesInk = Color.fuelVoltInk
}

// Corner radii — mirrors the web app's `--radius: 1.1rem` (≈18pt) for cards and
// `radius-sm` (≈12pt) for smaller elements (inputs, chips). Keep content cards
// on `.card` so the whole app shares one silhouette.
enum FuelRadius {
  static let card: CGFloat = 18
  static let small: CGFloat = 12
}

extension View {
  /// A dark Liquid-Glass content card: a translucent `.regular` glass panel with
  /// continuous corners and a hairline light edge. Mirrors the web app's dark
  /// identity (charcoal canvas, faint `white/3` translucent cards) while leaning
  /// into the iOS 26 glass material so cards read as frosted glass, not flat
  /// fills. Content cards stay shadowless — depth comes from the glass, not drops.
  func fuelCard(radius: CGFloat = FuelRadius.card) -> some View {
    self
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
      )
  }
}
