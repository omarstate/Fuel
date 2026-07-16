import * as React from "react"
import { cn } from "@/lib/utils"
import { BadgeMorph, type Status as MorphStatus } from "@/components/ui/badge-morph"

export type { MorphStatus }
export type MorphIntent = "default" | "destructive"
export type MorphVariant = "pill" | "inline"

export interface MorphButtonProps {
  /** Uncontrolled: provide onAction. Return true/undefined = success; false or throw = error. */
  onAction?: () => Promise<boolean | void>
  /** Controlled: parent owns status; overrides internal state. */
  status?: MorphStatus
  onClick?: React.MouseEventHandler<HTMLButtonElement>

  idleLabel: string
  loadingLabel?: string
  successLabel?: string
  errorLabel?: string
  idleIcon?: React.ComponentType<{ className?: string }>

  intent?: MorphIntent
  variant?: MorphVariant
  type?: "button" | "submit"
  resetDelay?: number
  onSuccess?: () => void
  onError?: () => void
  disabled?: boolean
  className?: string
  "aria-label"?: string
}

/** Red accent/glow to reuse for destructive-intent success (deletion reads red, not green). */
const DESTRUCTIVE_SUCCESS_OVERRIDE_CLASS =
  "[&_.text-emerald-500]:text-red-500"

export function MorphButton({
  onAction,
  status: controlledStatus,
  onClick,
  idleLabel,
  loadingLabel = "Saving…",
  successLabel,
  errorLabel = "Failed",
  idleIcon: IdleIcon,
  intent = "default",
  variant = "pill",
  type = "button",
  resetDelay = 1300,
  onSuccess,
  onError,
  disabled = false,
  className,
  "aria-label": ariaLabel,
}: MorphButtonProps) {
  const [internalStatus, setInternalStatus] = React.useState<MorphStatus>("idle")
  const isControlled = controlledStatus !== undefined
  const status = isControlled ? controlledStatus : internalStatus
  const resolvedSuccessLabel =
    successLabel ?? (intent === "destructive" ? "Deleted" : "Done")

  const resetTimer = React.useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  React.useEffect(() => {
    return () => {
      if (resetTimer.current) clearTimeout(resetTimer.current)
    }
  }, [])

  async function handleUncontrolledClick() {
    if (!onAction || status !== "idle") return
    setInternalStatus("loading")
    let result: boolean | void
    try {
      result = await onAction()
      setInternalStatus(result === false ? "error" : "success")
    } catch {
      setInternalStatus("error")
      result = false
    }

    const succeeded = result !== false
    resetTimer.current = setTimeout(() => {
      if (succeeded) onSuccess?.()
      else onError?.()
      setInternalStatus("idle")
    }, resetDelay)
  }

  function handleClick(e: React.MouseEvent<HTMLButtonElement>) {
    if (isControlled) {
      onClick?.(e)
      return
    }
    void handleUncontrolledClick()
  }

  const label =
    status === "idle"
      ? idleLabel
      : status === "loading"
        ? loadingLabel
        : status === "success"
          ? resolvedSuccessLabel
          : errorLabel

  const isDestructiveSuccess = intent === "destructive" && status === "success"
  const isBusy = status !== "idle"

  if (variant === "inline") {
    if (status === "idle") {
      return (
        <button
          type={type}
          onClick={handleClick}
          disabled={disabled}
          aria-label={ariaLabel ?? idleLabel}
          className={cn(
            "grid size-9 shrink-0 place-items-center rounded-md text-muted-foreground transition-all hover:bg-muted hover:text-destructive disabled:pointer-events-none disabled:opacity-50 sm:size-7",
            className
          )}
        >
          {IdleIcon && <IdleIcon className="size-4 sm:size-3.5" />}
        </button>
      )
    }

    return (
      <button
        type={type}
        onClick={handleClick}
        disabled={isBusy || disabled}
        aria-label={ariaLabel ?? idleLabel}
        className={cn(
          "inline-flex shrink-0 cursor-not-allowed",
          isDestructiveSuccess && DESTRUCTIVE_SUCCESS_OVERRIDE_CLASS
        )}
      >
        <BadgeMorph status={status} label={label} className="px-2.5 py-1 text-[12px]" />
      </button>
    )
  }

  if (status === "idle" && IdleIcon) {
    return (
      <button
        type={type}
        onClick={handleClick}
        disabled={disabled}
        aria-label={ariaLabel}
        className={cn(
          "inline-flex shrink-0 items-center gap-2 rounded-full bg-[#14120f] px-3.5 py-2.5 text-sm font-medium text-[#f7f3ea] transition-colors hover:bg-[#2a251d] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 sm:px-3 sm:py-1.5 sm:text-[13px]",
          className
        )}
      >
        <IdleIcon className="size-4 sm:size-3.5" />
        {idleLabel}
      </button>
    )
  }

  return (
    <button
      type={type}
      onClick={handleClick}
      disabled={isBusy || disabled}
      aria-label={ariaLabel}
      className={cn(
        "inline-flex shrink-0",
        (isBusy || disabled) && "cursor-not-allowed",
        disabled && !isBusy && "opacity-50",
        isDestructiveSuccess && DESTRUCTIVE_SUCCESS_OVERRIDE_CLASS,
        className
      )}
    >
      <BadgeMorph status={status} label={label} />
    </button>
  )
}
