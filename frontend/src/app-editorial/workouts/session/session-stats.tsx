import * as React from "react"
import { animate } from "framer-motion"
import { cn } from "@/lib/utils"

/** Tween-in number — counts toward `value` whenever it changes. */
function AnimatedNumber({ value }: { value: number }) {
  const ref = React.useRef<HTMLSpanElement>(null)
  const prevRef = React.useRef(0)

  React.useEffect(() => {
    const controls = animate(prevRef.current, value, {
      duration: 0.6,
      ease: "easeOut",
      onUpdate: (v) => {
        if (ref.current) ref.current.textContent = Math.round(v).toLocaleString()
      },
    })
    prevRef.current = value
    return () => controls.stop()
  }, [value])

  return <span ref={ref}>{value.toLocaleString()}</span>
}

function StatCell({
  label,
  value,
  unit,
  highlight = false,
}: {
  label: string
  value: number
  unit?: string
  highlight?: boolean
}) {
  return (
    <div
      className={cn(
        "rounded-xl border p-4",
        highlight
          ? "border-[var(--accent-ink)]/25 bg-[var(--accent-tint)]/50"
          : "border-border bg-card"
      )}
    >
      <div className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
        {label}
      </div>
      <div className="mt-1 font-mono text-2xl font-semibold tabular-nums text-foreground">
        <AnimatedNumber value={value} />
        {unit && <span className="ml-1 text-sm font-normal text-muted-foreground">{unit}</span>}
      </div>
    </div>
  )
}

/** Live session stats: exercises, sets, and total volume (Σ weight × reps).
 * Numbers tween up as sets land, so progress feels earned in real time. */
export function SessionStats({
  exercises,
  sets,
  volumeKg,
}: {
  exercises: number
  sets: number
  volumeKg: number
}) {
  return (
    <section className="grid grid-cols-3 gap-3 sm:gap-4">
      <StatCell label="Exercises" value={exercises} />
      <StatCell label="Sets" value={sets} />
      <StatCell label="Volume" value={volumeKg} unit="kg" highlight />
    </section>
  )
}
