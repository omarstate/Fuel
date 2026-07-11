const DAYS = ["M", "T", "W", "T", "F", "S", "S"]

export function WeekChart({
  accent,
  calories,
  goal,
}: {
  accent: string
  calories: number
  goal: number
}) {
  const jsDay = new Date().getDay() // 0 = Sun
  const todayIdx = (jsDay + 6) % 7 // Mon-first
  const todayPct = Math.min(calories / goal, 1)

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
            This week
          </div>
          <div className="mt-1 text-sm text-foreground">Calories vs goal</div>
        </div>
        <div className="flex items-center gap-3 font-mono text-[0.65rem] text-muted-foreground">
          <span className="flex items-center gap-1.5">
            <span
              className="size-2 rounded-full"
              style={{ backgroundColor: accent }}
            />
            Today
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-px w-3 border-t border-dashed border-muted-foreground" />
            Goal
          </span>
        </div>
      </div>

      <div className="relative mt-6 flex h-32 items-end gap-3">
        {/* goal line */}
        <div className="pointer-events-none absolute inset-x-0 top-3 border-t border-dashed border-border" />
        {DAYS.map((d, i) => {
          const isToday = i === todayIdx
          const isFuture = i > todayIdx
          const h = isToday ? Math.max(todayPct * 100, 3) : 0
          return (
            <div key={i} className="flex flex-1 flex-col items-center gap-2">
              <div className="flex h-full w-full items-end justify-center">
                <div
                  className="w-full max-w-9 rounded-t-sm transition-[height] duration-500"
                  style={{
                    height: `${Math.max(h, 2)}%`,
                    backgroundColor: isToday
                      ? accent
                      : "color-mix(in oklab, var(--foreground) 8%, transparent)",
                  }}
                />
              </div>
              <span
                className={`font-mono text-[0.65rem] ${
                  isToday
                    ? "font-semibold text-foreground"
                    : isFuture
                      ? "text-muted-foreground/50"
                      : "text-muted-foreground"
                }`}
              >
                {d}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
