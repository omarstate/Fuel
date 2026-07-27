import * as React from "react"
import { Minus, Plus } from "lucide-react"

/** Press-and-hold stepping: one step immediately, then repeat while held. */
export function useHoldRepeat(step: () => void) {
  const timeoutRef = React.useRef<number>(0)
  const intervalRef = React.useRef<number>(0)
  const stepRef = React.useRef(step)

  React.useEffect(() => {
    stepRef.current = step
  }, [step])

  const stop = React.useCallback(() => {
    window.clearTimeout(timeoutRef.current)
    window.clearInterval(intervalRef.current)
  }, [])

  const start = React.useCallback(() => {
    stepRef.current()
    timeoutRef.current = window.setTimeout(() => {
      intervalRef.current = window.setInterval(() => stepRef.current(), 110)
    }, 450)
  }, [])

  React.useEffect(() => stop, [stop])

  return {
    onPointerDown: start,
    onPointerUp: stop,
    onPointerLeave: stop,
    onPointerCancel: stop,
  }
}

export function Stepper({
  label,
  unit,
  value,
  onChange,
  onStep,
  inputMode,
}: {
  label: string
  unit: string
  value: string
  onChange: (v: string) => void
  onStep: (dir: 1 | -1) => void
  inputMode: "decimal" | "numeric"
}) {
  const dec = useHoldRepeat(() => onStep(-1))
  const inc = useHoldRepeat(() => onStep(1))

  return (
    <div className="flex flex-col gap-1">
      <span className="font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground">
        {label}
      </span>
      <div className="flex h-12 items-stretch overflow-hidden rounded-xl border border-border bg-card">
        <button
          type="button"
          {...dec}
          aria-label={`Decrease ${label}`}
          className="grid w-11 shrink-0 select-none place-items-center text-muted-foreground transition-colors hover:bg-muted hover:text-foreground active:bg-[var(--accent-tint)]"
        >
          <Minus className="size-4" />
        </button>
        <div className="flex min-w-0 flex-1 items-baseline justify-center gap-1 border-x border-border">
          <input
            type="number"
            inputMode={inputMode}
            min={0}
            value={value}
            placeholder="—"
            onChange={(e) => onChange(e.target.value)}
            onFocus={(e) => e.target.select()}
            className="w-full min-w-0 bg-transparent text-center font-mono text-xl font-semibold tabular-nums text-foreground outline-none placeholder:text-muted-foreground/50 [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
            aria-label={label}
          />
        </div>
        <button
          type="button"
          {...inc}
          aria-label={`Increase ${label}`}
          className="grid w-11 shrink-0 select-none place-items-center text-muted-foreground transition-colors hover:bg-muted hover:text-foreground active:bg-[var(--accent-tint)]"
        >
          <Plus className="size-4" />
        </button>
      </div>
      <span className="text-center font-mono text-[0.6rem] text-muted-foreground">{unit}</span>
    </div>
  )
}
