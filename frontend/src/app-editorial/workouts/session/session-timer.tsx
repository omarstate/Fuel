import * as React from "react"

/** Formats a duration in whole seconds as H:MM:SS. Reused by the live timer,
 * the history list, and the session detail header. */
export function formatDuration(totalSeconds: number): string {
  const seconds = Math.max(0, Math.round(totalSeconds))
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
}

/** Live "how long has this session been going" timer, ticking every second
 * and always derived from `startedAt` so a page refresh stays correct. */
export function SessionTimer({
  startedAt,
  className,
}: {
  startedAt: Date
  className?: string
}) {
  const [now, setNow] = React.useState(() => Date.now())

  React.useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [])

  const elapsedSeconds = Math.max(0, Math.floor((now - startedAt.getTime()) / 1000))

  return (
    <span className={className} aria-live="off">
      {formatDuration(elapsedSeconds)}
    </span>
  )
}
