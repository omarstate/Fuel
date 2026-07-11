import { AnimatePresence, motion } from "framer-motion"
import { Flame, TrendingUp } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { useMode, modeColors } from "@/components/site/mode-context"

const meals = [
  { name: "Breakfast", detail: "Oats, eggs, banana", kcal: 480 },
  { name: "Lunch", detail: "Chicken, rice, greens", kcal: 620 },
  { name: "Snack", detail: "Greek yogurt, almonds", kcal: 260 },
]

const lifts = [
  { name: "Bench press", detail: "4 × 6 @ 82.5 kg", pr: true },
  { name: "Incline DB press", detail: "3 × 10 @ 28 kg", pr: false },
  { name: "Cable fly", detail: "3 × 15 @ 18 kg", pr: false },
]

const bars = [40, 55, 48, 70, 62, 85, 78]

export function AppMockup() {
  const { mode } = useMode()
  const accent = modeColors[mode]

  return (
    <motion.div
      animate={{ y: [0, -10, 0] }}
      transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
      className="relative w-full max-w-sm rounded-3xl border border-bone/10 bg-char-2/90 p-5 shadow-2xl shadow-black/40 backdrop-blur"
    >
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-smoke">Today</span>
        <Badge
          variant="secondary"
          className="gap-1 border-0"
          style={{ backgroundColor: `${accent}1f`, color: accent }}
        >
          <Flame className="size-3" data-icon="inline-start" />
          6 day streak
        </Badge>
      </div>

      <AnimatePresence mode="wait">
        {mode === "nutrition" ? (
          <motion.div
            key="nutrition"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.25 }}
            className="mt-4"
          >
            <div className="flex items-center gap-4">
              <div
                className="relative flex size-20 shrink-0 items-center justify-center rounded-full"
                style={{
                  background: `conic-gradient(${accent} 72%, color-mix(in oklab, ${accent} 15%, transparent) 0)`,
                }}
              >
                <div className="absolute inset-1.5 rounded-full bg-char-2" />
                <div className="relative text-center">
                  <div className="font-mono text-sm font-semibold text-bone">
                    1,840
                  </div>
                  <div className="text-[0.6rem] text-smoke">kcal</div>
                </div>
              </div>
            </div>

            <div className="mt-4 space-y-2">
              {meals.map((m) => (
                <div
                  key={m.name}
                  className="flex items-center justify-between rounded-xl bg-char px-3 py-2"
                >
                  <div>
                    <div className="text-sm text-bone">{m.name}</div>
                    <div className="text-xs text-smoke">{m.detail}</div>
                  </div>
                  <div className="font-mono text-xs text-smoke">
                    {m.kcal} kcal
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="workouts"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.25 }}
            className="mt-4"
          >
            <div className="flex items-center justify-between rounded-xl bg-char px-3 py-2.5">
              <span className="text-sm font-medium text-bone">Push day</span>
              <span
                className="flex items-center gap-1 font-mono text-xs"
                style={{ color: accent }}
              >
                <TrendingUp className="size-3" /> +2.5 kg PR
              </span>
            </div>

            <div className="mt-2 space-y-2">
              {lifts.map((l) => (
                <div
                  key={l.name}
                  className="flex items-center justify-between rounded-xl bg-char px-3 py-2"
                >
                  <div>
                    <div className="text-sm text-bone">{l.name}</div>
                    <div className="font-mono text-xs text-smoke">
                      {l.detail}
                    </div>
                  </div>
                  {l.pr && (
                    <Badge
                      className="border-0 text-[0.65rem]"
                      style={{ backgroundColor: `${accent}1f`, color: accent }}
                    >
                      PR
                    </Badge>
                  )}
                </div>
              ))}
            </div>

            <div className="mt-4 flex h-14 items-end gap-1.5">
              {bars.map((h, i) => (
                <div
                  key={i}
                  className="flex-1 rounded-sm"
                  style={{
                    height: `${h}%`,
                    backgroundColor:
                      i === bars.length - 1
                        ? accent
                        : "color-mix(in oklab, var(--bone) 14%, transparent)",
                  }}
                />
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  )
}
