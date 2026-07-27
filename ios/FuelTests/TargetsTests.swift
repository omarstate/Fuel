import Testing
@testable import Fuel

// Fixture table hand-computed from frontend/src/lib/nutrition.ts. If these fail,
// either the Swift port drifted or the TS math changed (keep both in sync).
@Suite("Targets math")
struct TargetsTests {

  @Test("male 30y 180cm 80kg goal 75 standard/moderate → cut")
  func maleCut() {
    // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780
    // TDEE = 1780 * 1.55 = 2759 ; cut - 500 = 2259 ; round10 = 2260
    // protein round(1.8*80)=144 ; fat round(0.25*2260/9)=63 ; carbs round((2260-576-567)/4)=279
    let input = TargetMath.Input(
      sex: .male, age: 30, heightCm: 180, weightKg: 80, goalWeightKg: 75,
      activityLevel: .moderate, pace: .standard
    )
    #expect(TargetMath.computeTargets(input) == Targets(calories: 2260, protein: 144, carbs: 279, fat: 63))
    #expect(TargetMath.computeDirection(weightKg: 80, goalWeightKg: 75) == .cut)
  }

  @Test("small female aggressive cut hits the 1200 floor")
  func calorieFloor() {
    // BMR = 10*45 + 6.25*150 - 5*25 - 161 = 1101.5
    // TDEE = 1101.5 * 1.2 = 1321.8 ; cut - 750 = 571.8 ; floored to 1200 ; round10 = 1200
    // protein round(1.8*45)=81 ; fat round(0.25*1200/9)=33 ; carbs round((1200-324-297)/4)=145
    let input = TargetMath.Input(
      sex: .female, age: 25, heightCm: 150, weightKg: 45, goalWeightKg: 40,
      activityLevel: .sedentary, pace: .aggressive
    )
    #expect(TargetMath.computeTargets(input) == Targets(calories: 1200, protein: 81, carbs: 145, fat: 33))
  }

  @Test("goal within ±0.5kg maintains (no pace adjustment)")
  func maintainDeadBand() {
    // weight 82, goal 82.3 → maintain. BMR = 820 + 1093.75 - 200 + 5 = 1718.75
    // TDEE = 1718.75 * 1.55 = 2664.0625 ; round10 = 2660
    // protein round(1.8*82)=148 ; fat round(0.25*2660/9)=74 ; carbs round((2660-592-666)/4)=351
    let input = TargetMath.Input(
      sex: .male, age: 40, heightCm: 175, weightKg: 82, goalWeightKg: 82.3,
      activityLevel: .moderate, pace: .standard
    )
    #expect(TargetMath.computeDirection(weightKg: 82, goalWeightKg: 82.3) == .maintain)
    #expect(TargetMath.computeTargets(input) == Targets(calories: 2660, protein: 148, carbs: 351, fat: 74))
  }

  @Test("direction boundaries")
  func directionBoundaries() {
    // exactly -0.5 kg is a cut; exactly +0.5 kg is a bulk.
    #expect(TargetMath.computeDirection(weightKg: 80, goalWeightKg: 79.5) == .cut)
    #expect(TargetMath.computeDirection(weightKg: 80, goalWeightKg: 80.5) == .bulk)
    #expect(TargetMath.computeDirection(weightKg: 80, goalWeightKg: 80.4) == .maintain)
    #expect(TargetMath.computeDirection(weightKg: 80, goalWeightKg: 79.6) == .maintain)
  }

  @Test("raw calories round to the nearest 10")
  func roundingToTen() {
    // female 28y 165cm 62kg goal 62 light → maintain.
    // BMR = 620 + 1031.25 - 140 - 161 = 1350.25 ; TDEE = *1.375 = 1856.59375
    // round10 = round(185.659)=186 *10 = 1860
    let input = TargetMath.Input(
      sex: .female, age: 28, heightCm: 165, weightKg: 62, goalWeightKg: 62,
      activityLevel: .light, pace: .mild
    )
    let targets = TargetMath.computeTargets(input)
    #expect(targets.calories == 1860)
    #expect(targets.calories % 10 == 0)
  }

  @Test("bulk adds the pace magnitude")
  func bulk() {
    // male 22y 178cm 70kg goal 78 very/aggressive → bulk +750.
    // BMR = 700 + 1112.5 - 110 + 5 = 1707.5 ; TDEE = *1.725 = 2945.4375
    // + 750 = 3695.4375 ; round10 = 3700
    // protein round(1.8*70)=126 ; fat round(0.25*3700/9)=103 ; carbs round((3700-504-927)/4)=567
    let input = TargetMath.Input(
      sex: .male, age: 22, heightCm: 178, weightKg: 70, goalWeightKg: 78,
      activityLevel: .very, pace: .aggressive
    )
    #expect(TargetMath.computeTargets(input) == Targets(calories: 3700, protein: 126, carbs: 567, fat: 103))
  }

  @Test("DEFAULT_TARGETS constant")
  func defaults() {
    #expect(TargetMath.defaultTargets == Targets(calories: 2200, protein: 165, carbs: 220, fat: 70))
    #expect(TargetMath.kcalPerKg == 7700)
  }
}
