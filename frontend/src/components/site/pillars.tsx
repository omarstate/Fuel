import { motion } from "framer-motion"
import { Utensils, Dumbbell, Check } from "lucide-react"
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card"
import { useMode, modeColors, type Mode } from "@/components/site/mode-context"
import { cn } from "@/lib/utils"

const pillars: {
  mode: Mode
  icon: typeof Utensils
  title: string
  description: string
  points: string[]
}[] = [
  {
    mode: "nutrition",
    icon: Utensils,
    title: "Meals",
    description: "What you eat, without the spreadsheet.",
    points: [
      "Log a meal in 3 taps, photo optional",
      "Macro rings that fill as you eat",
      "Calories and macros, not just a number",
    ],
  },
  {
    mode: "workouts",
    icon: Dumbbell,
    title: "Lifts",
    description: "Every set, every rep, every PR.",
    points: [
      "Sets and reps logged mid-workout",
      "PRs flagged the moment you beat them",
      "Rest timer that starts itself",
    ],
  },
]

export function Pillars() {
  const { mode, setMode } = useMode()

  return (
    <section id="pillars" className="border-b border-bone/10 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5 }}
          className="max-w-xl"
        >
          <h2 className="font-heading text-3xl font-semibold tracking-tight text-bone sm:text-4xl">
            Two tracks. One streak.
          </h2>
          <p className="mt-3 text-smoke">
            Fuel keeps food and training in the same place, because your
            body treats them as one system, even when your apps don't.
          </p>
        </motion.div>

        <div className="mt-12 grid gap-6 md:grid-cols-2">
          {pillars.map((pillar, i) => {
            const accent = modeColors[pillar.mode]
            const active = mode === pillar.mode
            return (
              <motion.div
                key={pillar.mode}
                initial={{ opacity: 0, y: 24, rotate: i === 0 ? -1.5 : 1.5 }}
                whileInView={{ opacity: 1, y: 0, rotate: 0 }}
                viewport={{ once: true, margin: "-80px" }}
                transition={{ duration: 0.5, delay: i * 0.1 }}
              >
                <Card
                  onMouseEnter={() => setMode(pillar.mode)}
                  className={cn(
                    "h-full cursor-pointer p-2 ring-1 transition-shadow",
                    active ? "shadow-lg" : "shadow-none"
                  )}
                  style={{
                    boxShadow: active ? `0 0 0 1px ${accent}55` : undefined,
                  }}
                >
                  <CardHeader>
                    <div
                      className="mb-3 flex size-11 items-center justify-center rounded-xl"
                      style={{ backgroundColor: `${accent}1f`, color: accent }}
                    >
                      <pillar.icon className="size-5" />
                    </div>
                    <CardTitle className="text-xl">{pillar.title}</CardTitle>
                    <CardDescription>{pillar.description}</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <ul className="space-y-2.5">
                      {pillar.points.map((point) => (
                        <li
                          key={point}
                          className="flex items-start gap-2 text-sm text-bone/90"
                        >
                          <Check
                            className="mt-0.5 size-4 shrink-0"
                            style={{ color: accent }}
                          />
                          {point}
                        </li>
                      ))}
                    </ul>
                  </CardContent>
                </Card>
              </motion.div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
