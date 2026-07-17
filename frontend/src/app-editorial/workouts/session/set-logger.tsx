import * as React from "react"
import { motion } from "framer-motion"
import { Minus, Plus, Zap } from "lucide-react"
import { cn } from "@/lib/utils"

/** Press-and-hold stepping: one step immediately, then repeat while held. */
function useHoldRepeat(step: () => void) {
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

/** Deterministic pseudo-random particle burst, re-fired whenever `seed`
 * increments. Rendered inside a relative container, bursting from its center. */
function Burst({ seed }: { seed: number }) {
  const particles = React.useMemo(() => {
    if (seed === 0) return []
    return Array.from({ length: 14 }, (_, i) => ({
      angle: (i / 14) * Math.PI * 2 + ((seed + i) % 5) * 0.13,
      dist: 44 + ((i * 37 + seed * 11) % 40),
      size: 4 + ((i * 13) % 5),
      tone: i % 3,
    }))
  }, [seed])

  if (seed === 0) return null

  const tones = ["bg-[var(--primary)]", "bg-[var(--accent-ink)]", "bg-foreground/60"]

  return (
    <div aria-hidden className="pointer-events-none absolute inset-0">
      {particles.map((p, i) => (
        <motion.span
          key={`${seed}-${i}`}
          className={cn("absolute left-1/2 top-1/2 rounded-full", tones[p.tone])}
          style={{ width: p.size, height: p.size, marginLeft: -p.size / 2, marginTop: -p.size / 2 }}
          initial={{ x: 0, y: 0, opacity: 1, scale: 1 }}
          animate={{
            x: Math.cos(p.angle) * p.dist,
            y: Math.sin(p.angle) * p.dist,
            opacity: 0,
            scale: 0.2,
          }}
          transition={{ duration: 0.65, ease: "easeOut" }}
        />
      ))}
    </div>
  )
}

function Stepper({
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

const fmtWeight = (w: number) => (Number.isInteger(w) ? String(w) : w.toFixed(1))

/** One-tap set logging: steppers prefilled from the previous set, so a repeat
 * set is a single press of the big button. Fires a particle burst per log. */
export function SetLogger({
  defaultWeight,
  defaultReps,
  onLog,
}: {
  defaultWeight: number | null
  defaultReps: number | null
  onLog: (input: { weight: number | null; reps: number | null; note: string | null }) => Promise<boolean>
}) {
  const [weight, setWeight] = React.useState(
    defaultWeight === null ? "" : fmtWeight(defaultWeight)
  )
  const [reps, setReps] = React.useState(defaultReps === null ? "" : String(defaultReps))
  const [busy, setBusy] = React.useState(false)
  const [burstSeed, setBurstSeed] = React.useState(0)

  const stepWeight = (dir: 1 | -1) => {
    setWeight((w) => {
      const next = Math.max(0, (Number(w) || 0) + dir * 2.5)
      return next === 0 ? "" : fmtWeight(next)
    })
  }

  const stepReps = (dir: 1 | -1) => {
    setReps((r) => {
      const next = Math.max(0, (Number(r) || 0) + dir)
      return next === 0 ? "" : String(next)
    })
  }

  const weightNum = weight.trim() === "" ? null : Number(weight)
  const repsNum = reps.trim() === "" ? null : Number(reps)
  const canLog = !busy && ((repsNum ?? 0) > 0 || (weightNum ?? 0) > 0)

  async function log() {
    if (!canLog) return
    setBusy(true)
    const ok = await onLog({
      weight: Number.isNaN(weightNum as number) ? null : weightNum,
      reps: Number.isNaN(repsNum as number) ? null : repsNum,
      note: null,
    })
    setBusy(false)
    if (ok) setBurstSeed((s) => s + 1)
  }

  const summary =
    weightNum || repsNum
      ? `Log ${weightNum ? `${fmtWeight(weightNum)} kg` : "BW"} × ${repsNum ?? "—"}`
      : "Log set"

  return (
    <div className="grid grid-cols-2 items-end gap-2 sm:grid-cols-[1fr_1fr_1.4fr]">
      <Stepper
        label="Weight"
        unit="kg · ±2.5"
        value={weight}
        onChange={setWeight}
        onStep={stepWeight}
        inputMode="decimal"
      />
      <Stepper
        label="Reps"
        unit="±1"
        value={reps}
        onChange={setReps}
        onStep={stepReps}
        inputMode="numeric"
      />
      <div className="relative col-span-2 sm:col-span-1">
        <motion.button
          type="button"
          onClick={log}
          disabled={!canLog}
          whileTap={{ scale: 0.96 }}
          animate={burstSeed > 0 ? { scale: [1, 1.06, 1] } : undefined}
          transition={{ duration: 0.3 }}
          key={`log-${burstSeed}`}
          className={cn(
            "flex h-12 w-full items-center justify-center gap-2 rounded-xl font-heading text-base font-semibold tracking-tight transition-colors",
            canLog
              ? "bg-[#14120f] text-[#f7f3ea] hover:bg-[#2a251d]"
              : "cursor-not-allowed bg-muted text-muted-foreground"
          )}
        >
          <Zap className={cn("size-4", canLog && "text-[var(--primary)]")} />
          {busy ? "Logging…" : summary}
        </motion.button>
        <Burst seed={burstSeed} />
      </div>
    </div>
  )
}
