import Foundation

// PURE Foundation port of frontend/src/lib/nutrition.ts (mirror of the
// authoritative backend/src/utils/compute-targets.js). No SwiftUI / Supabase
// imports — unit-tested against a fixture table hand-computed from the TS.
//
// If the TS math ever changes, change it here too (and the backend).

enum Sex: String, Codable, CaseIterable, Sendable {
  case male
  case female
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
  case sedentary
  case light
  case moderate
  case very
  case extra

  var multiplier: Double {
    switch self {
    case .sedentary: return 1.2
    case .light: return 1.375
    case .moderate: return 1.55
    case .very: return 1.725
    case .extra: return 1.9
    }
  }

  var label: String {
    switch self {
    case .sedentary: return String(localized: "Sedentary")
    case .light: return String(localized: "Lightly active")
    case .moderate: return String(localized: "Moderately active")
    case .very: return String(localized: "Very active")
    case .extra: return String(localized: "Extra active")
    }
  }

  var hint: String {
    switch self {
    case .sedentary: return String(localized: "Little or no exercise")
    case .light: return String(localized: "Light exercise 1–3 days/week")
    case .moderate: return String(localized: "Moderate exercise 3–5 days/week")
    case .very: return String(localized: "Hard exercise 6–7 days/week")
    case .extra: return String(localized: "Physical job or training twice a day")
    }
  }
}

enum Pace: String, Codable, CaseIterable, Sendable {
  case mild
  case standard
  case aggressive

  var magnitude: Double {
    switch self {
    case .mild: return 250
    case .standard: return 500
    case .aggressive: return 750
    }
  }

  var label: String {
    switch self {
    case .mild: return String(localized: "Mild")
    case .standard: return String(localized: "Standard")
    case .aggressive: return String(localized: "Aggressive")
    }
  }

  var hint: String {
    switch self {
    case .mild: return String(localized: "≈0.25 kg/week")
    case .standard: return String(localized: "≈0.5 kg/week")
    case .aggressive: return String(localized: "≈0.75 kg/week")
    }
  }
}

enum Direction: String, Sendable {
  case cut
  case bulk
  case maintain
}

// Daily calorie + macro targets.
struct Targets: Equatable, Sendable {
  var calories: Int
  var protein: Int
  var carbs: Int
  var fat: Int
}

enum TargetMath {
  // Today's hardcoded goals — used as the fallback until a profile exists.
  static let defaultTargets = Targets(calories: 2200, protein: 165, carbs: 220, fat: 70)

  /// Approximate energy in one kg of body mass.
  static let kcalPerKg: Double = 7700

  static let calorieFloor: Double = 1200
  static let maintainDeadBandKg: Double = 0.5

  // The subset of profile inputs the math needs.
  struct Input: Equatable, Sendable {
    var sex: Sex
    var age: Double
    var heightCm: Double
    var weightKg: Double
    var goalWeightKg: Double
    var activityLevel: ActivityLevel
    var pace: Pace
  }

  private static func roundToNearest10(_ value: Double) -> Int {
    Int((value / 10).rounded()) * 10
  }

  private static func computeBmr(_ input: Input) -> Double {
    let base = 10 * input.weightKg + 6.25 * input.heightCm - 5 * input.age
    return input.sex == .male ? base + 5 : base - 161
  }

  static func computeDirection(weightKg: Double, goalWeightKg: Double) -> Direction {
    if goalWeightKg <= weightKg - maintainDeadBandKg { return .cut }
    if goalWeightKg >= weightKg + maintainDeadBandKg { return .bulk }
    return .maintain
  }

  static func computeTargets(_ input: Input) -> Targets {
    let bmr = computeBmr(input)
    let tdee = bmr * input.activityLevel.multiplier

    let direction = computeDirection(weightKg: input.weightKg, goalWeightKg: input.goalWeightKg)
    let paceMagnitude = input.pace.magnitude

    var rawCalories = tdee
    if direction == .cut { rawCalories = tdee - paceMagnitude }
    if direction == .bulk { rawCalories = tdee + paceMagnitude }

    let flooredCalories = max(rawCalories, calorieFloor)
    let calories = roundToNearest10(flooredCalories)

    let protein = Int((1.8 * input.weightKg).rounded())
    let fat = Int((0.25 * Double(calories) / 9).rounded())
    let carbs = max(0, Int(((Double(calories) - Double(protein) * 4 - Double(fat) * 9) / 4).rounded()))

    return Targets(calories: calories, protein: protein, carbs: carbs, fat: fat)
  }
}
