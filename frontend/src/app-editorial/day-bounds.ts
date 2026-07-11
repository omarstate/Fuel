/** Local-calendar-day helpers shared by the "today" meal log and the 30-day
 * meal history, so both agree on where one day ends and the next begins. */

export function startOfDay(date: Date): Date {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  return d
}

export function addDays(date: Date, days: number): Date {
  const d = new Date(date)
  d.setDate(d.getDate() + days)
  return d
}

/** Local YYYY-MM-DD key for grouping timestamps into calendar days. */
export function dayKey(date: Date): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, "0")
  const d = String(date.getDate()).padStart(2, "0")
  return `${y}-${m}-${d}`
}

/** Milliseconds until the next local midnight, for scheduling a refresh. */
export function msUntilNextMidnight(from: Date = new Date()): number {
  return addDays(startOfDay(from), 1).getTime() - from.getTime()
}
