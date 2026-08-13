import Testing
import Foundation
@testable import Fuel

// Guards on the numbers a language model hands us before they reach a
// numeric(6,2) column. The two decisions worth pinning: zero weight is
// BODYWEIGHT (nil), not a light set; and the 500 kg bound is checked BEFORE
// rounding, so 500.004 is rejected rather than quietly rounded into a legal 500.
@Suite("Set math")
struct SetMathTests {
  // MARK: - clampWeight

  @Test("A plausible weight passes through, rounded to the column's 2 places")
  func weightInRange() {
    #expect(SetMath.clampWeight(80) == 80)
    #expect(SetMath.clampWeight(82.5) == 82.5)
    #expect(SetMath.clampWeight(0.5) == 0.5)
    #expect(SetMath.clampWeight(62.499) == 62.5)
    #expect(SetMath.clampWeight(62.494) == 62.49)
    #expect(SetMath.clampWeight(500) == 500)
  }

  @Test("Zero and negatives are bodyweight or nonsense — nil, never 0 kg")
  func weightAtOrBelowZero() {
    #expect(SetMath.clampWeight(0) == nil)
    #expect(SetMath.clampWeight(-5) == nil)
    #expect(SetMath.clampWeight(nil) == nil)
  }

  @Test("Anything over 500 kg is a mis-hearing, not a lift")
  func weightAboveCeiling() {
    #expect(SetMath.clampWeight(500.004) == nil)   // rejected, NOT rounded to 500
    #expect(SetMath.clampWeight(501) == nil)
    #expect(SetMath.clampWeight(8_000) == nil)
  }

  @Test("Non-finite values are rejected")
  func weightNonFinite() {
    #expect(SetMath.clampWeight(.infinity) == nil)
    #expect(SetMath.clampWeight(.nan) == nil)
  }

  // MARK: - clampReps

  @Test("Reps pass through inside [1, 100]")
  func repsInRange() {
    #expect(SetMath.clampReps(1) == 1)
    #expect(SetMath.clampReps(8) == 8)
    #expect(SetMath.clampReps(100) == 100)
  }

  @Test("Zero reps is not a set, and three digits is a mis-heard weight")
  func repsOutOfRange() {
    #expect(SetMath.clampReps(0) == nil)
    #expect(SetMath.clampReps(-3) == nil)
    #expect(SetMath.clampReps(101) == nil)
    #expect(SetMath.clampReps(nil) == nil)
  }

  // MARK: - volume

  @Test("Volume sums weight × reps over persisted sets")
  func volumeOverSessionSets() {
    let exerciseID = UUID()
    let userID = UUID()
    let sets = [
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: 80, reps: 8),
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 85, reps: 6),
    ]
    #expect(SetMath.volume(sets: sets) == 640 + 510)
  }

  @Test("A bodyweight or rep-less set contributes nothing rather than skewing the total")
  func volumeWithNils() {
    let exerciseID = UUID()
    let userID = UUID()
    let sets = [
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 1, weight: nil, reps: 12),
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 2, weight: 20, reps: nil),
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: 3, weight: 40, reps: 5),
    ]
    #expect(SetMath.volume(sets: sets) == 200)
  }

  @Test("The unpersisted overload totals rows that don't exist in the database yet")
  func volumeOverPendingRows() {
    let pending: [(weight: Double?, reps: Int?)] = [(80, 8), (nil, 10), (82.5, 4)]
    let empty: [(weight: Double?, reps: Int?)] = []
    let unusable: [(weight: Double?, reps: Int?)] = [(nil, nil)]
    #expect(SetMath.volume(sets: pending) == 640 + 330)
    #expect(SetMath.volume(sets: empty) == 0)
    #expect(SetMath.volume(sets: unusable) == 0)
  }

  // MARK: - Set numbering lives in SessionStats, not here

  @Test("Numbering still comes from SessionStats, continuing past a deleted set")
  func numberingIsNotDuplicated() {
    let exerciseID = UUID()
    let userID = UUID()
    let existing = [1, 3].map {
      SessionSet(sessionExerciseId: exerciseID, userId: userID, setNumber: $0, weight: 60, reps: 8)
    }
    #expect(SessionStats.nextSetNumber(existing: existing) == 4)
  }
}
