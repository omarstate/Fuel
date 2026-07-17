import * as React from "react"
import { AnimatePresence, motion } from "framer-motion"
import { Minus, Plus, Play, X, Volume2, VolumeX } from "lucide-react"
import { cn } from "@/lib/utils"

/** Rest presets in seconds. */
const PRESETS = [60, 90, 120, 180]

const DURATION_KEY = "fuel.rest.duration"
const SOUND_KEY = "fuel.rest.sound"

/** Short, punchy lines rotated while resting. Editorial tone — no cheese. */
const QUOTES = [
  "Rest hard. Lift harder.",
  "Muscles grow between the sets.",
  "Breathe. The next set is yours.",
  "Shake it out. Stay loose.",
  "You vs. you — you're winning.",
  "Strong is built one set at a time.",
  "Water break. You've earned it.",
  "Every rep counts. So does every breath.",
  "Nobody's watching. Do it for you.",
  "One quality set beats three sloppy ones.",
  "Show up. Log it. Level up.",
  "Discipline shows up even when motivation doesn't.",
]

function fmtRest(totalSeconds: number): string {
  const s = Math.max(0, totalSeconds)
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}

function vibrate(pattern: number | number[]) {
  try {
    if ("vibrate" in navigator) navigator.vibrate(pattern)
  } catch {
    /* unsupported — fine */
  }
}

/** Two quick ascending sine notes — "rest over, go". */
function beep(ctx: AudioContext) {
  const note = (freq: number, at: number) => {
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = freq
    osc.type = "sine"
    gain.gain.setValueAtTime(0.0001, ctx.currentTime + at)
    gain.gain.exponentialRampToValueAtTime(0.25, ctx.currentTime + at + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + at + 0.18)
    osc.connect(gain).connect(ctx.destination)
    osc.start(ctx.currentTime + at)
    osc.stop(ctx.currentTime + at + 0.2)
  }
  note(880, 0)
  note(1318, 0.18)
}

export type RestTimer = {
  state: "idle" | "running" | "done"
  secondsLeft: number
  /** Total seconds of the current rest, for the progress ring. */
  total: number
  duration: number
  setDuration: (d: number) => void
  /** (Re)start a rest — called manually or automatically after a logged set. */
  start: (d?: number) => void
  skip: () => void
  adjust: (delta: number) => void
  soundOn: boolean
  toggleSound: () => void
  /** Increments every rest — used to vary the quote rotation. */
  restCount: number
}

export function useRestTimer(): RestTimer {
  const [duration, setDurationState] = React.useState(() => {
    const stored = Number(localStorage.getItem(DURATION_KEY))
    return PRESETS.includes(stored) ? stored : 90
  })
  const [soundOn, setSoundOn] = React.useState(
    () => localStorage.getItem(SOUND_KEY) !== "off"
  )
  const [state, setState] = React.useState<RestTimer["state"]>("idle")
  const [secondsLeft, setSecondsLeft] = React.useState(0)
  const [total, setTotal] = React.useState(90)
  const [restCount, setRestCount] = React.useState(0)
  const endsAtRef = React.useRef(0)
  const audioRef = React.useRef<AudioContext | null>(null)

  const setDuration = React.useCallback((d: number) => {
    setDurationState(d)
    localStorage.setItem(DURATION_KEY, String(d))
  }, [])

  const toggleSound = React.useCallback(() => {
    setSoundOn((on) => {
      localStorage.setItem(SOUND_KEY, on ? "off" : "on")
      return !on
    })
  }, [])

  const start = React.useCallback(
    (d?: number) => {
      const seconds = d ?? duration
      // AudioContext must be created during a user gesture; logging a set is one.
      if (!audioRef.current) {
        try {
          audioRef.current = new AudioContext()
        } catch {
          /* no audio — vibration still works */
        }
      }
      endsAtRef.current = Date.now() + seconds * 1000
      setTotal(seconds)
      setSecondsLeft(seconds)
      setRestCount((c) => c + 1)
      setState("running")
    },
    [duration]
  )

  const skip = React.useCallback(() => setState("idle"), [])

  const adjust = React.useCallback((delta: number) => {
    endsAtRef.current += delta * 1000
    const left = Math.max(0, Math.ceil((endsAtRef.current - Date.now()) / 1000))
    setSecondsLeft(left)
    setTotal((t) => Math.max(t, left))
  }, [])

  // Tick — derived from the end timestamp so background tabs stay accurate.
  React.useEffect(() => {
    if (state !== "running") return
    const id = window.setInterval(() => {
      const left = Math.ceil((endsAtRef.current - Date.now()) / 1000)
      if (left <= 0) {
        setSecondsLeft(0)
        setState("done")
        vibrate([200, 100, 200])
        if (audioRef.current && localStorage.getItem(SOUND_KEY) !== "off") {
          beep(audioRef.current)
        }
      } else {
        setSecondsLeft(left)
      }
    }, 250)
    return () => window.clearInterval(id)
  }, [state])

  // "GO" flash auto-dismisses back to idle.
  React.useEffect(() => {
    if (state !== "done") return
    const id = window.setTimeout(() => setState("idle"), 3000)
    return () => window.clearTimeout(id)
  }, [state])

  return {
    state,
    secondsLeft,
    total,
    duration,
    setDuration,
    start,
    skip,
    adjust,
    soundOn,
    toggleSound,
    restCount,
  }
}

function ProgressRing({ ratio }: { ratio: number }) {
  const r = 17
  const c = 2 * Math.PI * r
  return (
    <svg viewBox="0 0 40 40" className="size-10 -rotate-90">
      <circle cx="20" cy="20" r={r} fill="none" strokeWidth="3" className="stroke-border" />
      <circle
        cx="20"
        cy="20"
        r={r}
        fill="none"
        strokeWidth="3"
        strokeLinecap="round"
        className="stroke-[var(--accent-ink)] transition-[stroke-dashoffset] duration-300 ease-linear"
        strokeDasharray={c}
        strokeDashoffset={c * (1 - Math.min(1, Math.max(0, ratio)))}
      />
    </svg>
  )
}

/** Floating rest-timer bar, fixed to the bottom of the active-session page.
 * Idle: preset chips + start. Running: countdown ring, ±15s, skip, rotating
 * motivation. Done: full-accent "GO" flash with vibration/beep. */
export function RestTimerBar({ timer }: { timer: RestTimer }) {
  const { state, secondsLeft, total, duration, setDuration, start, skip, adjust } = timer

  const quoteIndex =
    (timer.restCount * 3 + Math.floor((total - secondsLeft) / 8)) % QUOTES.length

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-4 z-40 flex justify-center px-4">
      <AnimatePresence mode="wait" initial={false}>
        {state === "idle" && (
          <motion.div
            key="idle"
            initial={{ y: 24, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 24, opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="pointer-events-auto flex items-center gap-2 rounded-full border border-border bg-card/95 py-1.5 pl-4 pr-1.5 shadow-lg backdrop-blur"
          >
            <span className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
              Rest
            </span>
            <div className="flex items-center gap-1">
              {PRESETS.map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setDuration(p)}
                  className={cn(
                    "rounded-full px-2.5 py-1.5 font-mono text-xs tabular-nums transition-colors",
                    p === duration
                      ? "bg-[var(--accent-tint)] font-semibold text-[var(--accent-ink)]"
                      : "text-muted-foreground hover:text-foreground"
                  )}
                >
                  {fmtRest(p)}
                </button>
              ))}
            </div>
            <button
              type="button"
              onClick={() => start()}
              aria-label="Start rest timer"
              className="grid size-9 place-items-center rounded-full bg-[#14120f] text-[#f7f3ea] transition-transform hover:scale-105 active:scale-95"
            >
              <Play className="size-4 fill-current" />
            </button>
          </motion.div>
        )}

        {state === "running" && (
          <motion.div
            key="running"
            initial={{ y: 24, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 24, opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="pointer-events-auto flex w-full max-w-sm flex-col gap-1 rounded-2xl border border-border bg-card/95 px-4 py-3 shadow-lg backdrop-blur"
          >
            <div className="flex items-center gap-3">
              <div className="relative grid place-items-center">
                <ProgressRing ratio={secondsLeft / total} />
              </div>
              <div className="flex-1">
                <div className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
                  Resting
                </div>
                <div
                  className={cn(
                    "font-mono text-2xl font-semibold tabular-nums leading-none",
                    secondsLeft <= 5
                      ? "animate-pulse text-[var(--accent-ink)]"
                      : "text-foreground"
                  )}
                >
                  {fmtRest(secondsLeft)}
                </div>
              </div>
              <div className="flex items-center gap-1">
                <button
                  type="button"
                  onClick={() => adjust(-15)}
                  aria-label="Shorten rest by 15 seconds"
                  className="grid size-9 place-items-center rounded-full border border-border text-muted-foreground transition-colors hover:text-foreground"
                >
                  <Minus className="size-4" />
                </button>
                <button
                  type="button"
                  onClick={() => adjust(15)}
                  aria-label="Extend rest by 15 seconds"
                  className="grid size-9 place-items-center rounded-full border border-border text-muted-foreground transition-colors hover:text-foreground"
                >
                  <Plus className="size-4" />
                </button>
                <button
                  type="button"
                  onClick={timer.toggleSound}
                  aria-label={timer.soundOn ? "Mute end-of-rest sound" : "Unmute end-of-rest sound"}
                  className="grid size-9 place-items-center rounded-full border border-border text-muted-foreground transition-colors hover:text-foreground"
                >
                  {timer.soundOn ? <Volume2 className="size-4" /> : <VolumeX className="size-4" />}
                </button>
                <button
                  type="button"
                  onClick={skip}
                  aria-label="Skip rest"
                  className="grid size-9 place-items-center rounded-full bg-[#14120f] text-[#f7f3ea] transition-transform hover:scale-105 active:scale-95"
                >
                  <X className="size-4" />
                </button>
              </div>
            </div>
            <AnimatePresence mode="wait">
              <motion.p
                key={quoteIndex}
                initial={{ opacity: 0, y: 4 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -4 }}
                transition={{ duration: 0.3 }}
                className="pl-13 text-center text-xs italic text-muted-foreground"
              >
                {QUOTES[quoteIndex]}
              </motion.p>
            </AnimatePresence>
          </motion.div>
        )}

        {state === "done" && (
          <motion.button
            key="done"
            type="button"
            onClick={skip}
            initial={{ y: 24, opacity: 0, scale: 0.9 }}
            animate={{ y: 0, opacity: 1, scale: [1, 1.04, 1] }}
            exit={{ y: 24, opacity: 0 }}
            transition={{
              duration: 0.3,
              scale: { duration: 0.8, repeat: Infinity },
            }}
            className="pointer-events-auto flex w-full max-w-sm items-center justify-center gap-2 rounded-2xl bg-[var(--primary)] px-4 py-4 font-heading text-lg font-semibold tracking-tight text-[#14120f] shadow-lg"
          >
            Rest over — GO 💥
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  )
}
