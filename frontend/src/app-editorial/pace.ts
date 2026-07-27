/** Time-of-day calorie pacing. Given what's been eaten so far and the daily
 * goal, judges whether intake is tracking the part of the day that's elapsed —
 * so the card can say "on pace" vs "ahead of pace" instead of only showing a
 * remaining number that means nothing without knowing what time it is. */

// Assumed waking eating window (local hours). Pace is measured against how far
// through this window we are, not the full 24h — nobody eats evenly overnight.
const WAKE_START = 8
const WAKE_END = 22
/** Tolerance around the expected-by-now figure before calling it off-pace. */
const TOLERANCE = 0.08

export type PaceStatus = "over" | "ahead" | "on" | "behind"

// i18n key for the human label; translated at the render site (see
// macro-summary.tsx). Keeping the key here (not the string) so the util stays
// pure and the copy lives in the dictionaries.
export type PaceLabelKey =
  | "pace.overGoal"
  | "pace.aheadOfPace"
  | "pace.roomToSpare"
  | "pace.onPace"

export type Pace = {
  /** Goal minus consumed. Negative once over goal. */
  remaining: number
  status: PaceStatus
  labelKey: PaceLabelKey
}

export function computePace(consumed: number, goal: number, now: Date = new Date()): Pace {
  const remaining = goal - consumed

  if (consumed > goal) {
    return { remaining, status: "over", labelKey: "pace.overGoal" }
  }

  const hour = now.getHours() + now.getMinutes() / 60
  const frac = Math.min(Math.max((hour - WAKE_START) / (WAKE_END - WAKE_START), 0), 1)
  const expected = goal * frac
  const tol = goal * TOLERANCE

  if (consumed > expected + tol) return { remaining, status: "ahead", labelKey: "pace.aheadOfPace" }
  if (consumed < expected - tol) return { remaining, status: "behind", labelKey: "pace.roomToSpare" }
  return { remaining, status: "on", labelKey: "pace.onPace" }
}
