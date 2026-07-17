// Pure function: a set of ISO date strings (or Date-parseable values) -> the
// user's current and best activity streaks, measured in consecutive UTC
// calendar days. No DB access.
//
// A streak is "alive" if the most recent activity day was today or yesterday
// (UTC); `current` counts back from there. `best` is the longest run anywhere
// in the input window.

const toUtcDayKey = (value) => {
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return null
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(
    d.getUTCDate()
  ).padStart(2, "0")}`
}

const dayKeyToUtcMillis = (key) => {
  const [y, m, d] = key.split("-").map(Number)
  return Date.UTC(y, m - 1, d)
}

const DAY_MS = 24 * 60 * 60 * 1000

export const computeStreak = (isoDates, today = new Date()) => {
  const uniqueKeys = [...new Set(isoDates.map(toUtcDayKey).filter(Boolean))]
  if (uniqueKeys.length === 0) return { current: 0, best: 0 }

  const sorted = uniqueKeys.map(dayKeyToUtcMillis).sort((a, b) => a - b)

  // best: longest run of consecutive days anywhere in the window.
  let best = 1
  let run = 1
  for (let i = 1; i < sorted.length; i += 1) {
    if (sorted[i] - sorted[i - 1] === DAY_MS) {
      run += 1
    } else {
      run = 1
    }
    if (run > best) best = run
  }

  // current: run ending at today or yesterday.
  const todayKey = toUtcDayKey(today)
  const todayMs = dayKeyToUtcMillis(todayKey)
  const mostRecent = sorted[sorted.length - 1]
  const gapFromToday = (todayMs - mostRecent) / DAY_MS

  let current = 0
  if (gapFromToday === 0 || gapFromToday === 1) {
    current = 1
    for (let i = sorted.length - 2; i >= 0; i -= 1) {
      if (sorted[i + 1] - sorted[i] === DAY_MS) {
        current += 1
      } else {
        break
      }
    }
  }

  return { current, best }
}
