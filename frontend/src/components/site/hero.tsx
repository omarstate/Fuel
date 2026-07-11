import { AnimatePresence, motion } from "framer-motion"
import { ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ModeToggle } from "@/components/site/mode-toggle"
import { AppMockup } from "@/components/site/app-mockup"
import { BackgroundBlobs } from "@/components/site/background-blobs"
import { useMode, modeColors } from "@/components/site/mode-context"

const wordByMode = { nutrition: "meal", workouts: "set" }

function scrollTo(id: string) {
  document.querySelector(id)?.scrollIntoView({ behavior: "smooth" })
}

export function Hero() {
  const { mode } = useMode()
  const accent = modeColors[mode]

  return (
    <section
      id="top"
      className="relative overflow-hidden border-b border-bone/10"
    >
      <BackgroundBlobs />

      <div className="relative mx-auto grid max-w-6xl gap-16 px-6 py-20 md:grid-cols-2 md:items-center md:py-28">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
        >
          <Badge variant="secondary" className="mb-6">
            One log for food and training
          </Badge>

          <h1 className="font-heading text-5xl font-semibold leading-[1.05] tracking-tight text-bone sm:text-6xl">
            Log every{" "}
            <span className="relative inline-block">
              <AnimatePresence mode="wait">
                <motion.span
                  key={mode}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0, color: accent }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.25 }}
                  className="inline-block"
                >
                  {wordByMode[mode]}
                </motion.span>
              </AnimatePresence>
              .
            </span>
            <br />
            Build the streak.
          </h1>

          <p className="mt-6 max-w-md text-lg text-smoke">
            Fuel is the logbook for your body — macros and meals on one
            side, sets and PRs on the other. Logged in seconds, not
            spreadsheets.
          </p>

          <div className="mt-8">
            <ModeToggle />
          </div>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Button size="lg" onClick={() => scrollTo("#join")}>
              Start free
              <ArrowRight data-icon="inline-end" />
            </Button>
            <Button
              size="lg"
              variant="outline"
              onClick={() => scrollTo("#pillars")}
            >
              See how it works
            </Button>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.94 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, ease: "easeOut", delay: 0.15 }}
          className="flex justify-center md:justify-end"
        >
          <AppMockup />
        </motion.div>
      </div>
    </section>
  )
}
