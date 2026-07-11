import * as React from "react"
import { motion } from "framer-motion"
import { cn } from "@/lib/utils"

export function QuickActionsRow({
  children,
  className,
}: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={cn("flex flex-wrap gap-3", className)}>{children}</div>
  )
}

type NativeButtonProps = Omit<
  React.ComponentProps<"button">,
  "onDrag" | "onDragStart" | "onDragEnd" | "onAnimationStart" | "onAnimationEnd" | "onAnimationIteration"
>

export const QuickActionButton = React.forwardRef<
  HTMLButtonElement,
  NativeButtonProps & {
    icon: React.ComponentType<{ className?: string }>
    label: string
    accent: string
    delay?: number
  }
>(function QuickActionButton(
  { icon: Icon, label, accent, delay = 0, className, ...props },
  ref
) {
  return (
    <motion.button
      ref={ref}
      type="button"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay }}
      whileHover={{ y: -2 }}
      whileTap={{ scale: 0.97 }}
      className={cn(
        "flex items-center gap-2.5 rounded-2xl border border-bone/10 bg-char-2 px-4 py-3 text-left text-sm font-medium text-bone transition-colors hover:bg-char-2/70",
        className
      )}
      {...props}
    >
      <span
        className="flex size-8 shrink-0 items-center justify-center rounded-xl"
        style={{ backgroundColor: `${accent}1f`, color: accent }}
      >
        <Icon className="size-4" />
      </span>
      {label}
    </motion.button>
  )
})
