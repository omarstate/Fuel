import { motion } from "framer-motion"
import { Utensils, Dumbbell } from "lucide-react"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { useMode, modeColors, type Mode } from "@/components/site/mode-context"
import { cn } from "@/lib/utils"

const options: { value: Mode; label: string; icon: typeof Utensils }[] = [
  { value: "nutrition", label: "Nutrition", icon: Utensils },
  { value: "workouts", label: "Workouts", icon: Dumbbell },
]

export function ModeToggle({
  className,
  value,
  onValueChange,
}: {
  className?: string
  /** Defaults to the shared ModeContext when not provided. */
  value?: Mode
  onValueChange?: (mode: Mode) => void
}) {
  const { mode: contextMode, setMode } = useMode()
  const mode = value ?? contextMode
  const handleChange = onValueChange ?? setMode

  return (
    <ToggleGroup
      type="single"
      value={mode}
      onValueChange={(value) => value && handleChange(value as Mode)}
      spacing={0}
      className={cn(
        "relative rounded-full bg-char-2 p-1 ring-1 ring-bone/10",
        className
      )}
      aria-label="Switch between nutrition and workouts"
    >
      {options.map(({ value, label, icon: Icon }) => (
        <ToggleGroupItem
          key={value}
          value={value}
          className="relative flex-1 justify-center rounded-full border-0 bg-transparent px-5 py-2 text-sm font-medium text-smoke data-[state=on]:bg-transparent data-[state=on]:text-char"
        >
          {mode === value && (
            <motion.span
              layoutId="mode-toggle-pill"
              className="absolute inset-0 rounded-full"
              animate={{ backgroundColor: modeColors[mode] }}
              transition={{
                layout: { type: "spring", stiffness: 500, damping: 35 },
                backgroundColor: { duration: 0.25 },
              }}
            />
          )}
          <span className="relative z-10 flex items-center gap-1.5">
            <Icon className="size-3.5" data-icon="inline-start" />
            {label}
          </span>
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}
