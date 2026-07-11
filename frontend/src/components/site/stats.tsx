import * as React from "react"
import { motion } from "framer-motion"
import { Progress } from "@/components/ui/progress"
import { useCountUp } from "@/hooks/use-count-up"

const stats = [
  { value: 48213, label: "Meals logged this month", suffix: "" },
  { value: 912400, label: "Kilograms lifted this month", suffix: " kg" },
  { value: 62, label: "Average workouts a week", suffix: "", decimals: true },
  { value: 14, label: "Median streak, in days", suffix: "" },
]

function Stat({
  value,
  label,
  suffix,
  decimals,
}: (typeof stats)[number]) {
  const { ref, value: current } = useCountUp(value)
  const display = decimals ? (current / 10).toFixed(1) : current.toLocaleString()

  return (
    <div ref={ref as React.RefObject<HTMLDivElement>}>
      <div className="font-mono text-4xl font-semibold text-bone sm:text-5xl">
        {display}
        {suffix}
      </div>
      <p className="mt-2 text-sm text-smoke">{label}</p>
    </div>
  )
}

export function Stats() {
  return (
    <section id="stats" className="border-b border-bone/10 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="font-heading text-3xl font-semibold tracking-tight text-bone sm:text-4xl">
            People show up more when both sides are logged.
          </h2>
        </motion.div>

        <div className="mt-12 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((s, i) => (
            <motion.div
              key={s.label}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{ duration: 0.5, delay: i * 0.08 }}
            >
              <Stat {...s} />
            </motion.div>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="mt-14 max-w-md rounded-2xl border border-bone/10 bg-char-2 p-5"
        >
          <div className="flex items-center justify-between text-sm">
            <span className="text-bone">This week's streak</span>
            <span className="font-mono text-smoke">5 / 7 days</span>
          </div>
          <Progress value={71} className="mt-3" />
        </motion.div>
      </div>
    </section>
  )
}
