import * as React from "react"
import { Sparkles, ExternalLink, Loader2 } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { AddToLogButton } from "@/app-editorial/add-to-log-button"
import { invalidateMealsCache } from "@/app-editorial/library/use-paged-meals"
import { aiLookupMeals, type AiLookupItem, type CatalogMeal } from "@/lib/api"
import { useI18n } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/en"
import { cn } from "@/lib/utils"

const SEARCHING_HINT_KEYS: MessageKey[] = [
  "lookup.hint.searching",
  "lookup.hint.reading",
  "lookup.hint.checking",
  "lookup.hint.crunching",
]

function hostOf(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "")
  } catch {
    return url
  }
}

function kcalLabel(meal: CatalogMeal, formatNumber: (n: number) => string): string {
  const range = meal.macroRanges?.calories
  if (meal.aiSource === "estimate" && range) return `${formatNumber(range[0])}–${formatNumber(range[1])}`
  return formatNumber(meal.calories)
}

function ResultCard({ item }: { item: AiLookupItem }) {
  const { meal, created } = item
  const { t, formatNumber, localizeDigits } = useI18n()

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-border bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="truncate text-[0.95rem] font-medium text-foreground">{localizeDigits(meal.name)}</div>
          <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1">
            {meal.aiSource === "estimate" ? (
              <span className="rounded-md bg-amber-500/15 px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-amber-700 dark:text-amber-400">
                {t("lookup.aiEstimate")}
              </span>
            ) : meal.aiSource === "official" ? (
              <span className="rounded-md bg-[#d9fa36]/15 px-2 py-0.5 font-mono text-[0.6rem] uppercase tracking-wide text-[#5c6d0a]">
                {t("lookup.official")}
              </span>
            ) : null}
            {meal.servingSize && (
              <span className="font-mono text-[0.7rem] uppercase tracking-[0.12em] text-muted-foreground">
                {localizeDigits(meal.servingSize)}
              </span>
            )}
            {!created && (
              <span className="font-mono text-[0.6rem] uppercase tracking-wide text-muted-foreground">
                {t("lookup.alreadyInLibrary")}
              </span>
            )}
          </div>
        </div>
        <div className="shrink-0 text-end">
          <div className="font-mono text-lg font-semibold leading-none text-foreground">
            {kcalLabel(meal, formatNumber)}
          </div>
          <div className="mt-1 font-mono text-[0.6rem] uppercase tracking-widest text-muted-foreground">
            {t("common.kcal")}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-x-3 overflow-hidden font-mono text-xs whitespace-nowrap text-muted-foreground">
          <span>
            <span className="text-[#b5431c]">P</span> {formatNumber(meal.protein)}
          </span>
          <span>
            <span className="text-[#a9781f]">C</span> {formatNumber(meal.carbs)}
          </span>
          <span>
            <span className="text-[#5c6d0a]">F</span> {formatNumber(meal.fat)}
          </span>
        </div>

        <div onClick={(e) => e.stopPropagation()}>
          <AddToLogButton meal={meal} className="sm:text-xs" />
        </div>
      </div>

      {meal.sourceUrl && (
        <a
          href={meal.sourceUrl}
          target="_blank"
          rel="noopener noreferrer"
          onClick={(e) => e.stopPropagation()}
          className="inline-flex w-fit items-center gap-1 font-mono text-[0.65rem] text-muted-foreground transition-colors hover:text-foreground"
        >
          <ExternalLink className="size-3" />
          {hostOf(meal.sourceUrl)}
        </a>
      )}
    </div>
  )
}

export function AiMealLookupDialog({ trigger }: { trigger: React.ReactNode }) {
  const { t, lang } = useI18n()
  const [open, setOpen] = React.useState(false)
  const [query, setQuery] = React.useState("")
  const [status, setStatus] = React.useState<"idle" | "searching" | "done" | "error">("idle")
  const [items, setItems] = React.useState<AiLookupItem[]>([])
  const [errorMsg, setErrorMsg] = React.useState<string | null>(null)
  const [hintIndex, setHintIndex] = React.useState(0)
  const activeRef = React.useRef(0)

  // Rotate the searching hint while a request is in flight.
  React.useEffect(() => {
    if (status !== "searching") return
    const timer = setInterval(() => {
      setHintIndex((i) => (i + 1) % SEARCHING_HINT_KEYS.length)
    }, 2200)
    return () => clearInterval(timer)
  }, [status])

  function reset() {
    setQuery("")
    setStatus("idle")
    setItems([])
    setErrorMsg(null)
    setHintIndex(0)
  }

  async function runSearch() {
    const q = query.trim()
    if (q.length < 2 || status === "searching") return

    const requestId = activeRef.current + 1
    activeRef.current = requestId
    setStatus("searching")
    setErrorMsg(null)
    setItems([])

    try {
      const res = await aiLookupMeals(q, lang)
      if (activeRef.current !== requestId) return
      // A lookup can create brand-new catalog meals — bust the library cache
      // so they show up next time the paged library is read.
      if (res.items.some((item) => item.created)) invalidateMealsCache()
      setItems(res.items)
      setStatus("done")
    } catch (err) {
      if (activeRef.current !== requestId) return
      setErrorMsg(err instanceof Error ? err.message : t("lookup.lookupFailed"))
      setStatus("error")
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) {
          // Ignore any in-flight result once the dialog closes.
          activeRef.current += 1
          reset()
        }
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            {t("today.aiLookup")}
          </div>
          <DialogTitle className="font-heading text-lg">{t("lookup.title")}</DialogTitle>
          <DialogDescription>
            {t("lookup.description")}
          </DialogDescription>
        </DialogHeader>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            void runSearch()
          }}
          className="flex items-center gap-2"
        >
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t("lookup.placeholder")}
            className="h-9"
            autoFocus
          />
          <Button
            type="submit"
            disabled={query.trim().length < 2 || status === "searching"}
          >
            {status === "searching" ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Sparkles className="size-4" />
            )}
            {t("common.search")}
          </Button>
        </form>

        {status === "searching" && (
          <div className="flex flex-col gap-3 py-1">
            <div className="flex items-center gap-2 font-mono text-xs text-muted-foreground">
              <Loader2 className="size-3.5 animate-spin" />
              {t(SEARCHING_HINT_KEYS[hintIndex])}
            </div>
            {[0, 1].map((i) => (
              <div
                key={i}
                className={cn("h-20 animate-pulse rounded-lg bg-muted")}
                style={{ opacity: 1 - i * 0.3 }}
              />
            ))}
          </div>
        )}

        {status === "error" && (
          <div className="flex flex-col items-start gap-3 rounded-lg border border-border bg-card p-4">
            <p className="text-sm text-muted-foreground">{errorMsg}</p>
            <Button variant="outline" size="sm" onClick={() => void runSearch()}>
              {t("common.retry")}
            </Button>
          </div>
        )}

        {status === "done" && items.length === 0 && (
          <div className="rounded-lg border border-border bg-card px-4 py-8 text-center text-sm text-muted-foreground">
            {t("lookup.noResults")}
          </div>
        )}

        {status === "done" && items.length > 0 && (
          <div className="flex flex-col gap-3">
            {items.map((item) => (
              <ResultCard key={item.meal.id} item={item} />
            ))}
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
