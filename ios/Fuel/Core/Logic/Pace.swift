import Foundation

// PURE Foundation port of frontend/src/app-editorial/pace.ts. Time-of-day
// calorie pacing: given what's been eaten and the daily goal, judges whether
// intake is tracking the part of the waking day that's elapsed — so the card
// can say "on pace" vs "ahead of pace" instead of only a remaining number.
//
// Named `CaloriePace` / `PaceStatus` / `PaceReading` to avoid colliding with
// the weight-loss `Pace` enum in Targets.swift.

enum PaceStatus: String, Sendable, Equatable {
  case over
  case ahead
  case on
  case behind
}

// i18n key for the human label (mirrors `PaceLabelKey` in the TS). The English
// copy matches lib/i18n/en.ts exactly; it is lowercase and title-cased at the
// render site.
enum PaceLabelKey: String, Sendable, Equatable {
  case overGoal = "pace.overGoal"
  case aheadOfPace = "pace.aheadOfPace"
  case roomToSpare = "pace.roomToSpare"
  case onPace = "pace.onPace"

  var text: String {
    switch self {
    case .overGoal: return "over goal"
    case .aheadOfPace: return "ahead of pace"
    case .roomToSpare: return "room to spare"
    case .onPace: return "on pace"
    }
  }
}

struct PaceReading: Sendable, Equatable {
  /// Goal minus consumed. Negative once over goal.
  let remaining: Int
  let status: PaceStatus
  let labelKey: PaceLabelKey

  var label: String { labelKey.text }
}

enum CaloriePace {
  // Assumed waking eating window (local hours). Pace is measured against how far
  // through this window we are, not the full 24h.
  static let wakeStart: Double = 8
  static let wakeEnd: Double = 22
  /// Tolerance around the expected-by-now figure before calling it off-pace.
  static let tolerance: Double = 0.08

  static func compute(
    consumed: Int,
    goal: Int,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> PaceReading {
    let remaining = goal - consumed

    // `over` is checked first — being past goal beats any time-of-day reasoning.
    if consumed > goal {
      return PaceReading(remaining: remaining, status: .over, labelKey: .overGoal)
    }

    let comps = calendar.dateComponents([.hour, .minute], from: now)
    let hour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    let frac = min(max((hour - wakeStart) / (wakeEnd - wakeStart), 0), 1)
    let expected = Double(goal) * frac
    let tol = Double(goal) * tolerance
    let eaten = Double(consumed)

    if eaten > expected + tol {
      return PaceReading(remaining: remaining, status: .ahead, labelKey: .aheadOfPace)
    }
    if eaten < expected - tol {
      return PaceReading(remaining: remaining, status: .behind, labelKey: .roomToSpare)
    }
    return PaceReading(remaining: remaining, status: .on, labelKey: .onPace)
  }
}
