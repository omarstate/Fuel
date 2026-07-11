import { motion } from "framer-motion"
import { useMode, modeColors } from "@/components/site/mode-context"

export function BackgroundBlobs() {
  const { mode } = useMode()

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      <motion.div
        className="absolute -left-40 top-[-10%] size-[36rem] rounded-full blur-3xl"
        animate={{
          backgroundColor: modeColors[mode],
          x: [0, 40, 0],
          y: [0, 30, 0],
        }}
        transition={{
          backgroundColor: { duration: 0.6, ease: "easeOut" },
          x: { duration: 16, repeat: Infinity, ease: "easeInOut" },
          y: { duration: 18, repeat: Infinity, ease: "easeInOut" },
        }}
        style={{ opacity: 0.16 }}
      />
      <motion.div
        className="absolute right-[-12rem] top-[15%] size-[28rem] rounded-full blur-3xl"
        animate={{
          backgroundColor:
            mode === "nutrition" ? modeColors.workouts : modeColors.nutrition,
          x: [0, -30, 0],
          y: [0, 40, 0],
        }}
        transition={{
          backgroundColor: { duration: 0.6, ease: "easeOut" },
          x: { duration: 20, repeat: Infinity, ease: "easeInOut" },
          y: { duration: 14, repeat: Infinity, ease: "easeInOut" },
        }}
        style={{ opacity: 0.1 }}
      />
    </div>
  )
}
