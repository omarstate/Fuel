import type { ComponentType } from "react"

export function StatCard({
  icon: Icon,
  label,
  value,
  unit,
  hint,
}: {
  icon: ComponentType<{ className?: string }>
  label: string
  value: string | number
  unit?: string
  hint?: string
}) {
  return (
    <div className="flex flex-col justify-between rounded-xl border border-border bg-card p-5">
      <div className="flex items-center justify-between">
        <span className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
          {label}
        </span>
        <Icon className="size-4 text-muted-foreground" />
      </div>
      <div className="mt-6 flex items-baseline gap-1">
        <span className="font-mono text-3xl font-semibold leading-none text-foreground">
          {value}
        </span>
        {unit && (
          <span className="font-mono text-sm text-muted-foreground">{unit}</span>
        )}
      </div>
      {hint && <div className="mt-1.5 text-xs text-muted-foreground">{hint}</div>}
    </div>
  )
}
