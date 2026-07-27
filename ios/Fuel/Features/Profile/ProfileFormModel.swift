import Foundation
import Observation

// Shared editable state for both onboarding and profile editing. Holds raw text
// for numeric fields (locale-parsed on demand) and exposes validation + a live
// target preview.
@MainActor
@Observable
final class ProfileFormModel {
  var sex: Sex = .male
  var ageText: String = ""
  var heightText: String = ""
  var weightText: String = ""
  var goalText: String = ""
  var activityLevel: ActivityLevel = .moderate
  var pace: Pace = .standard

  init() {}

  init(profile: Profile) {
    sex = profile.sex
    ageText = String(profile.age)
    heightText = Self.trimNumber(profile.heightCm)
    weightText = Self.trimNumber(profile.weightKg)
    goalText = Self.trimNumber(profile.goalWeightKg)
    activityLevel = profile.activityLevel
    pace = profile.pace
  }

  // MARK: - Parsed values

  var age: Int? { NumberParsing.int(ageText) }
  var heightCm: Double? { NumberParsing.double(heightText) }
  var weightKg: Double? { NumberParsing.double(weightText) }
  var goalWeightKg: Double? { NumberParsing.double(goalText) }

  // MARK: - Validation (matches backend zod ranges)

  var ageError: String? {
    guard let age else { return ageText.isEmpty ? nil : errorInvalid }
    return (13...120).contains(age) ? nil : String(localized: "Age must be between 13 and 120.")
  }

  var heightError: String? {
    guard let heightCm else { return heightText.isEmpty ? nil : errorInvalid }
    return (90...260).contains(heightCm) ? nil : String(localized: "Height must be 90–260 cm.")
  }

  var weightError: String? {
    guard let weightKg else { return weightText.isEmpty ? nil : errorInvalid }
    return (30...400).contains(weightKg) ? nil : String(localized: "Weight must be 30–400 kg.")
  }

  var goalError: String? {
    guard let goalWeightKg else { return goalText.isEmpty ? nil : errorInvalid }
    return (30...400).contains(goalWeightKg) ? nil : String(localized: "Goal weight must be 30–400 kg.")
  }

  private var errorInvalid: String { String(localized: "Enter a valid number.") }

  var isValid: Bool {
    guard let age, let heightCm, let weightKg, let goalWeightKg else { return false }
    return (13...120).contains(age)
      && (90...260).contains(heightCm)
      && (30...400).contains(weightKg)
      && (30...400).contains(goalWeightKg)
  }

  // MARK: - Outputs

  var profileInput: ProfileInput? {
    guard isValid, let age, let heightCm, let weightKg, let goalWeightKg else { return nil }
    return ProfileInput(
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      activityLevel: activityLevel,
      pace: pace
    )
  }

  /// Live preview targets, or nil until the form is valid.
  var previewTargets: Targets? {
    profileInput.map { TargetMath.computeTargets($0.targetInput) }
  }

  var direction: Direction? {
    guard let weightKg, let goalWeightKg else { return nil }
    return TargetMath.computeDirection(weightKg: weightKg, goalWeightKg: goalWeightKg)
  }

  private static func trimNumber(_ value: Double) -> String {
    if value == value.rounded() { return String(Int(value)) }
    return String(value)
  }
}
