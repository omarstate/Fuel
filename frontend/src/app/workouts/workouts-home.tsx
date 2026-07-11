import { motion } from "framer-motion"
import { Dumbbell } from "lucide-react"
import {
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  EmptyDescription,
} from "@/components/ui/empty"
import { useMode, modeColors } from "@/components/site/mode-context"

export function WorkoutsHome() {
  const { mode } = useMode()
  const accent = modeColors[mode]

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-8">
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <h1 className="font-heading text-3xl font-semibold tracking-tight text-bone">
          Workouts
        </h1>
        <p className="mt-1 text-smoke">Set logging is next up.</p>
      </motion.div>

      <Empty className="rounded-3xl border border-bone/10 bg-char-2">
        <EmptyHeader>
          <EmptyMedia
            variant="icon"
            style={{ backgroundColor: `${accent}1f`, color: accent }}
          >
            <Dumbbell className="size-5" />
          </EmptyMedia>
          <EmptyTitle>Workout logging is on the way</EmptyTitle>
          <EmptyDescription>
            We built Nutrition first. Sets, reps, and PRs land here next.
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    </div>
  )
}
