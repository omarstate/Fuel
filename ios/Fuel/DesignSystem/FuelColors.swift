import SwiftUI

// Brand color tokens, backed by color sets in Assets.xcassets (a single
// universal value each — the app locks to light, so no dark variants). Asset
// symbol generation is off, so these explicit extensions ARE the API.
//
// Usage convention (see DESIGN.md):
//   - `fuelVolt` / `fuelOlive` / `fuelGold` / `fuelOver` are FILL colors
//     (bars, dots, discs, chart bars).
//   - `*Ink` variants are for TEXT / icons / thin strokes — the fills are tuned
//     for saturation on cream, the inks for contrast against it.
extension Color {
  static let fuelBackground = Color("FuelBackground")
  static let fuelSurface = Color("FuelSurface")
  static let fuelInk = Color("FuelInk")
  static let fuelSubtle = Color("FuelSubtle")
  static let fuelVolt = Color("FuelVolt")
  static let fuelVoltInk = Color("FuelVoltInk")
  /// The brand green as a LARGE fill (progress bars, ring arcs, chart bars).
  /// Same green as volt — kept as a separate name so fill call-sites read right.
  static let fuelOlive = Color("FuelOlive")
  /// Over-target signal — warm terracotta (web `#c85a3c`), NOT alarm red. Also
  /// the fat macro fill and the snack section color.
  /// `fuelDestructive` is reserved for genuinely destructive actions (delete).
  static let fuelOver = Color("FuelOver")
  /// Terracotta TEXT/icons — `fuelOver` darkened enough to read on cream.
  static let fuelOverInk = Color("FuelOverInk")
  /// Brand accent green (buttons, links, active states). Note:
  /// `fuelCitrus`/`fuelCitrusInk` are historical names — they ARE the green
  /// brand accent (same green as volt/olive), kept so the many existing accent
  /// call-sites re-point without edits.
  static let fuelCitrus = Color("FuelCitrus")
  static let fuelCitrusInk = Color("FuelCitrusInk")
  /// Dinner-section blue (and any remaining blue readouts).
  static let fuelBlue = Color("FuelBlue")
  static let fuelBlueInk = Color("FuelBlueInk")
  static let fuelDestructive = Color("FuelDestructive")
  static let fuelGold = Color("FuelGold")
  static let fuelGoldInk = Color("FuelGoldInk")
  /// The WORKOUTS side accent — warm orange (web `editorialAccent.workouts`,
  /// `#ff6b35`). Workout-side screens tint primary actions/pills with this
  /// instead of the green; the cream canvas and cards stay identical.
  static let fuelWorkout = Color("FuelWorkout")
  /// Workout orange for TEXT/icons (web `#b5431c`) — darkened to read on cream.
  static let fuelWorkoutInk = Color("FuelWorkoutInk")
}

// Macro color convention (matches the light editorial mockup):
//   protein = green, carbs = gold, fat = terracotta, calories = green.
enum MacroPalette {
  static let proteinFill = Color.fuelOlive
  static let proteinInk = Color.fuelVoltInk
  static let carbsFill = Color.fuelGold
  static let carbsInk = Color.fuelGoldInk
  static let fatFill = Color.fuelOver
  static let fatInk = Color.fuelOverInk
  static let caloriesFill = Color.fuelOlive
  static let caloriesInk = Color.fuelVoltInk
}

// One color per meal section, shared by the Today section-card dots and the
// segments of the hero's stacked calorie bar so the two read as the same key.
enum MealTypePalette {
  static func color(_ type: MealType) -> Color {
    switch type {
    case .breakfast: return .fuelGold
    case .lunch: return .fuelOlive
    case .dinner: return .fuelBlue
    case .snack: return .fuelOver
    }
  }
}

// Corner radii — cards use 22pt continuous corners (the editorial mockup's
// roundness) and smaller elements (inputs, chips) 12pt. Keep content cards on
// `.card` so the whole app shares one silhouette.
enum FuelRadius {
  static let card: CGFloat = 22
  static let small: CGFloat = 12
}

extension View {
  /// An OPAQUE cream-white content card: a `fuelSurface` fill in continuous
  /// corners, a hairline ink edge, and one soft drop shadow. On the warm cream
  /// canvas the separation comes from the shadow, not from a material — glass is
  /// reserved for the floating layer (toolbars, chips, buttons), never content.
  func fuelCard(radius: CGFloat = FuelRadius.card) -> some View {
    fuelCard(in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }

  /// The same card recipe in an arbitrary shape, for any non-rectangular
  /// element that must match the cards it sits between.
  func fuelCard<S: InsettableShape>(in shape: S) -> some View {
    self
      .background(shape.fill(Color.fuelSurface))
      .overlay(shape.strokeBorder(Color.fuelInk.opacity(0.06), lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
  }
}
