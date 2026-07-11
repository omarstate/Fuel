import type { ReactNode } from "react"
import { motion } from "framer-motion"
import { Timer, Plus, LineChart, Camera } from "lucide-react"
import { Card } from "@/components/ui/card"

const bars = [30, 45, 38, 60, 52, 74, 68, 90]

export function FeatureBento() {
  return (
    <section id="features" className="border-b border-bone/10 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5 }}
          className="max-w-xl"
        >
          <h2 className="font-heading text-3xl font-semibold tracking-tight text-bone sm:text-4xl">
            Built to be logged mid-bite, mid-set.
          </h2>
          <p className="mt-3 text-smoke">
            Nothing here needs a desk. Every one of these takes less time
            than unlocking most apps.
          </p>
        </motion.div>

        <div className="mt-12 grid gap-5 md:grid-cols-3">
          <FeatureCard
            className="md:col-span-2"
            delay={0}
            title="Add a meal in 3 taps"
            description="Search, snap a photo, or repeat yesterday's lunch. Macros fill in themselves."
            icon={Plus}
          >
            <div className="mt-6 flex flex-wrap gap-2">
              {["Chicken bowl", "Protein shake", "Yesterday's lunch"].map(
                (chip) => (
                  <span
                    key={chip}
                    className="rounded-full bg-char px-3 py-1.5 text-xs text-bone/80 ring-1 ring-bone/10"
                  >
                    {chip}
                  </span>
                )
              )}
            </div>
          </FeatureCard>

          <FeatureCard
            delay={0.08}
            title="Photo, not typing"
            description="Point the camera at your plate. Fuel estimates the rest."
            icon={Camera}
          >
            <div className="mt-6 aspect-square w-full rounded-xl bg-gradient-to-br from-citrus/20 to-transparent ring-1 ring-bone/10" />
          </FeatureCard>

          <FeatureCard
            delay={0.16}
            title="Rest timer, built in"
            description="Starts the moment you log a set. No second app, no guessing."
            icon={Timer}
          >
            <div className="mt-6 flex items-center justify-center">
              <div className="relative flex size-20 items-center justify-center rounded-full ring-2 ring-volt/40">
                <span className="font-mono text-lg text-volt">1:32</span>
              </div>
            </div>
          </FeatureCard>

          <FeatureCard
            className="md:col-span-2"
            delay={0.24}
            title="Every lift, charted"
            description="See the exact week your bench press started moving. No spreadsheet required."
            icon={LineChart}
          >
            <div className="mt-6 flex h-20 items-end gap-2">
              {bars.map((h, i) => (
                <div
                  key={i}
                  className={
                    i === bars.length - 1
                      ? "flex-1 rounded-sm bg-volt"
                      : "flex-1 rounded-sm bg-bone/10"
                  }
                  style={{ height: `${h}%` }}
                />
              ))}
            </div>
          </FeatureCard>
        </div>
      </div>
    </section>
  )
}

function FeatureCard({
  title,
  description,
  icon: Icon,
  children,
  className,
  delay,
}: {
  title: string
  description: string
  icon: typeof Plus
  children?: ReactNode
  className?: string
  delay: number
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{ duration: 0.5, delay }}
      whileHover={{ y: -4 }}
      className={className}
    >
      <Card className="h-full p-6">
        <div className="flex size-9 items-center justify-center rounded-lg bg-bone/5 text-bone">
          <Icon className="size-4.5" />
        </div>
        <h3 className="mt-4 font-heading text-lg font-medium text-bone">
          {title}
        </h3>
        <p className="mt-1.5 text-sm text-smoke">{description}</p>
        {children}
      </Card>
    </motion.div>
  )
}
