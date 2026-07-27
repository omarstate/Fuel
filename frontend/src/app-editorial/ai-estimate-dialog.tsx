import * as React from "react"
import { toast } from "sonner"
import { Sparkles, ArrowLeft, MapPin } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { MorphButton, type MorphStatus } from "@/components/ui/morph-button"
import { cn } from "@/lib/utils"
import { estimateMeals, saveAiMealsToCatalog, type EstimatedMeal } from "@/lib/api"
import { invalidateMealsCache } from "@/app-editorial/library/use-paged-meals"
import { mealTypeLabel, type Meal, type MealType } from "@/app/nutrition/types"

/** Pick a sensible default meal type from the current local time. */
function defaultMealType(): MealType {
  const h = new Date().getHours()
  if (h < 11) return "breakfast"
  if (h < 16) return "lunch"
  if (h < 21) return "dinner"
  return "snack"
}

// Editable copy of an AI estimate — numeric fields are strings so the inputs
// stay controlled while the user tweaks them before saving.
type Row = {
  input: string
  name: string
  servingSize: string
  calories: string
  protein: string
  carbs: string
  fat: string
  source: EstimatedMeal["source"]
  confidence: EstimatedMeal["confidence"]
  note: string
  ok: boolean
}

function toRow(e: EstimatedMeal): Row {
  return {
    input: e.input,
    name: e.name,
    servingSize: e.servingSize,
    calories: String(e.calories),
    protein: String(e.protein),
    carbs: String(e.carbs),
    fat: String(e.fat),
    source: e.source,
    confidence: e.confidence,
    note: e.note,
    ok: e.ok,
  }
}

const sourceLabel: Record<NonNullable<EstimatedMeal["source"]>, string> = {
  egypt: "🇪🇬 Egypt",
  regional: "Regional",
  global: "Global",
}

function SourceBadge({ row }: { row: Row }) {
  if (!row.source) return null
  const tone =
    row.source === "egypt"
      ? "bg-[var(--accent-tint)] text-[var(--accent-ink)]"
      : "bg-muted text-muted-foreground"
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 font-mono text-[0.6rem] uppercase tracking-[0.1em]",
        tone
      )}
    >
      {sourceLabel[row.source]}
      {row.confidence ? ` · ${row.confidence}` : ""}
    </span>
  )
}

export function AiEstimateDialog({
  onAdd,
  trigger,
}: {
  onAdd: (meal: Meal) => Promise<boolean>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = React.useState(false)
  const [step, setStep] = React.useState<"input" | "review">("input")
  const [place, setPlace] = React.useState("")
  const [itemsText, setItemsText] = React.useState("")
  const [mealType, setMealType] = React.useState<MealType>(defaultMealType())
  const [estimating, setEstimating] = React.useState(false)
  const [rows, setRows] = React.useState<Row[]>([])
  const [saveStatus, setSaveStatus] = React.useState<MorphStatus>("idle")

  function reset() {
    setStep("input")
    setPlace("")
    setItemsText("")
    setMealType(defaultMealType())
    setEstimating(false)
    setRows([])
    setSaveStatus("idle")
  }

  const items = React.useMemo(
    () =>
      itemsText
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    [itemsText]
  )

  async function handleEstimate(e: React.FormEvent) {
    e.preventDefault()
    if (estimating || items.length === 0) return
    setEstimating(true)
    try {
      const results = await estimateMeals({ place: place.trim() || undefined, items })
      setRows(results.map(toRow))
      setStep("review")
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't estimate those meals.")
    } finally {
      setEstimating(false)
    }
  }

  function updateRow(index: number, patch: Partial<Row>) {
    setRows((prev) => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)))
  }

  async function handleSaveAll() {
    if (saveStatus !== "idle") return
    setSaveStatus("loading")
    const now = new Date()
    const usable = rows.filter((r) => r.name.trim() && r.calories !== "")

    if (usable.length === 0) {
      toast.error("Nothing to log — add a name and calories first.")
      setSaveStatus("idle")
      return
    }

    const meals: Meal[] = usable.map((r) => ({
      id: crypto.randomUUID(),
      name: r.name.trim(),
      mealType,
      servingSize: r.servingSize.trim() || undefined,
      calories: Number(r.calories) || 0,
      protein: Number(r.protein) || 0,
      carbs: Number(r.carbs) || 0,
      fat: Number(r.fat) || 0,
      loggedAt: now,
    }))

    // Two destinations: the user's daily log (feeds today's macros) and the
    // shared "AI" catalog (browsable/reusable). The catalog save is best-effort
    // — a failure there shouldn't block logging the day.
    const catalogInputs = usable.map((r) => ({
      name: r.name.trim(),
      description: r.note || undefined,
      servingSize: r.servingSize.trim() || undefined,
      calories: Number(r.calories) || 0,
      protein: Number(r.protein) || 0,
      carbs: Number(r.carbs) || 0,
      fat: Number(r.fat) || 0,
    }))

    const [logResults] = await Promise.all([
      Promise.all(meals.map((m) => onAdd(m))),
      saveAiMealsToCatalog(catalogInputs)
        .then(() => invalidateMealsCache())
        .catch(() => {
          toast.error("Logged your meal, but couldn't add it to the AI library.")
        }),
    ])

    const saved = logResults.filter(Boolean).length

    if (saved === 0) {
      setSaveStatus("error")
      setTimeout(() => setSaveStatus("idle"), 1300)
      return
    }

    setSaveStatus("success")
    toast.success(saved === 1 ? "Logged 1 meal." : `Logged ${saved} meals.`)
    setTimeout(() => {
      setOpen(false)
      reset()
    }, 1200)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (estimating || saveStatus === "loading") return
        setOpen(next)
        if (!next) reset()
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        {step === "input" ? (
          <form onSubmit={handleEstimate}>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Sparkles className="size-4 text-[var(--accent-ink)]" />
                Estimate with AI
              </DialogTitle>
              <DialogDescription>
                Tell us where you ate and list what you had, separated by commas.
                Each item is looked up individually — Egyptian menus and portions first.
              </DialogDescription>
            </DialogHeader>

            <FieldGroup className="mt-4">
              <Field>
                <FieldLabel htmlFor="ai-place">
                  Where did you eat from? <span className="text-muted-foreground">(optional)</span>
                </FieldLabel>
                <div className="relative">
                  <MapPin className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    id="ai-place"
                    className="pl-8"
                    placeholder="McDonald's"
                    value={place}
                    onChange={(e) => setPlace(e.target.value)}
                    autoFocus
                  />
                </div>
              </Field>

              <Field>
                <FieldLabel htmlFor="ai-items">What did you eat?</FieldLabel>
                <textarea
                  id="ai-items"
                  className="min-h-20 w-full rounded-lg border border-input bg-transparent px-2.5 py-2 text-base outline-none transition-colors placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 md:text-sm dark:bg-input/30"
                  placeholder="Big Mac, medium fries, Coke"
                  value={itemsText}
                  onChange={(e) => setItemsText(e.target.value)}
                  required
                />
                <p className="mt-1 text-xs text-muted-foreground">
                  Separate each item with a comma.
                  {items.length > 0 &&
                    ` ${items.length} item${items.length === 1 ? "" : "s"} detected.`}
                </p>
              </Field>

              <Field>
                <FieldLabel htmlFor="ai-meal-type">Meal</FieldLabel>
                <Select value={mealType} onValueChange={(v) => setMealType(v as MealType)}>
                  <SelectTrigger id="ai-meal-type" className="w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectGroup>
                      {Object.entries(mealTypeLabel).map(([value, label]) => (
                        <SelectItem key={value} value={value}>
                          {label}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  </SelectContent>
                </Select>
              </Field>
            </FieldGroup>

            <DialogFooter className="mt-6">
              <Button
                type="button"
                variant="outline"
                onClick={() => setOpen(false)}
                disabled={estimating}
                className="h-11 w-full sm:h-9 sm:w-auto"
              >
                Cancel
              </Button>
              <MorphButton
                type="submit"
                status={estimating ? "loading" : "idle"}
                onClick={() => {}}
                idleIcon={Sparkles}
                idleLabel="Estimate"
                loadingLabel="Searching…"
                disabled={items.length === 0}
                className="w-full sm:w-auto"
              />
            </DialogFooter>
          </form>
        ) : (
          <div>
            <DialogHeader>
              <DialogTitle>Review estimates</DialogTitle>
              <DialogDescription>
                Check the numbers and edit anything that looks off before logging
                {place.trim() ? ` your meal from ${place.trim()}` : ""}.
              </DialogDescription>
            </DialogHeader>

            <div className="mt-4 flex max-h-[52vh] flex-col gap-3 overflow-y-auto pr-1">
              {rows.map((row, i) => (
                <div key={i} className="rounded-xl border border-border bg-card p-3">
                  <div className="flex items-start justify-between gap-2">
                    <Input
                      value={row.name}
                      onChange={(e) => updateRow(i, { name: e.target.value })}
                      className="h-8 flex-1 font-medium"
                    />
                    <SourceBadge row={row} />
                  </div>

                  <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-5">
                    <label className="col-span-2 flex flex-col gap-1 sm:col-span-1">
                      <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                        Serving
                      </span>
                      <Input
                        value={row.servingSize}
                        onChange={(e) => updateRow(i, { servingSize: e.target.value })}
                        placeholder="1 serving"
                        className="h-8"
                      />
                    </label>
                    {(["calories", "protein", "carbs", "fat"] as const).map((k) => (
                      <label key={k} className="flex flex-col gap-1">
                        <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                          {k === "calories" ? "kcal" : `${k.slice(0, 1).toUpperCase()} (g)`}
                        </span>
                        <Input
                          type="number"
                          inputMode="numeric"
                          min={0}
                          value={row[k]}
                          onChange={(e) => updateRow(i, { [k]: e.target.value })}
                          className="h-8"
                        />
                      </label>
                    ))}
                  </div>

                  {row.note && (
                    <p
                      className={cn(
                        "mt-2 text-xs",
                        row.ok ? "text-muted-foreground" : "text-destructive"
                      )}
                    >
                      {row.note}
                    </p>
                  )}
                </div>
              ))}
            </div>

            <DialogFooter className="mt-6">
              <Button
                type="button"
                variant="outline"
                onClick={() => setStep("input")}
                disabled={saveStatus === "loading"}
                className="h-11 w-full gap-2 sm:h-9 sm:w-auto"
              >
                <ArrowLeft className="size-4" /> Back
              </Button>
              <MorphButton
                type="button"
                status={saveStatus}
                onClick={handleSaveAll}
                idleLabel={rows.length === 1 ? "Log meal" : `Log ${rows.length} meals`}
                loadingLabel="Logging…"
                successLabel="Logged"
                className="w-full sm:w-auto"
              />
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
