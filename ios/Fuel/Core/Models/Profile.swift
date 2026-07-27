import Foundation

// GET /api/profile -> Profile | null. Targets are server-computed and read-only
// on the client (we mirror the math for previews via TargetMath, but only the
// server persists them).
struct Profile: Codable, Equatable, Sendable {
  let userId: String
  let sex: Sex
  let age: Int
  let heightCm: Double
  let weightKg: Double
  let goalWeightKg: Double
  let activityLevel: ActivityLevel
  let pace: Pace
  let targetCalories: Int
  let targetProtein: Int
  let targetCarbs: Int
  let targetFat: Int
  let onboardedAt: Date?
  let updatedAt: Date?

  var targets: Targets {
    Targets(
      calories: targetCalories,
      protein: targetProtein,
      carbs: targetCarbs,
      fat: targetFat
    )
  }
}

// PUT /api/profile body — same fields minus the server-computed targets.
struct ProfileInput: Codable, Equatable, Sendable {
  var sex: Sex
  var age: Int
  var heightCm: Double
  var weightKg: Double
  var goalWeightKg: Double
  var activityLevel: ActivityLevel
  var pace: Pace

  /// Convert to the pure math input for a live target preview.
  var targetInput: TargetMath.Input {
    TargetMath.Input(
      sex: sex,
      age: Double(age),
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      activityLevel: activityLevel,
      pace: pace
    )
  }
}
