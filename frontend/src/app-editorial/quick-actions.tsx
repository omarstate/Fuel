import * as React from "react"
import { cn } from "@/lib/utils"

/** Refined inline log toolbar — segmented, flat, editorial. */
export function LogToolbar({
  children,
  className,
}: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-1 rounded-xl border border-border bg-card p-1",
        className
      )}
    >
      {children}
    </div>
  )
}

type NativeButtonProps = React.ComponentProps<"button">

export const LogAction = React.forwardRef<
  HTMLButtonElement,
  NativeButtonProps & {
    icon: React.ComponentType<{ className?: string }>
    label: string
    primary?: boolean
  }
>(function LogAction({ icon: Icon, label, primary = false, className, ...props }, ref) {
  return (
    <button
      ref={ref}
      type="button"
      className={cn(
        "inline-flex items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium transition-colors",
        primary
          ? "bg-[#14120f] text-[#f7f3ea] hover:bg-[#2a251d]"
          : "text-foreground hover:bg-muted",
        className
      )}
      {...props}
    >
      <Icon className={cn("size-4", primary ? "text-[#f7f3ea]" : "text-[var(--accent-ink)]")} />
      {label}
    </button>
  )
})
