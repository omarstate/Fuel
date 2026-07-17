import * as React from "react"
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
import {
  mealTypeLabel,
  suggestedMealType,
  type Meal,
  type MealType,
} from "@/app/nutrition/types"

const emptyForm = {
  name: "",
  mealType: "breakfast" as MealType,
  servingSize: "",
  calories: "",
  protein: "",
  carbs: "",
  fat: "",
}

export function AddMealDialog({
  onAdd,
  trigger,
  defaultMealType,
  open: controlledOpen,
  onOpenChange: controlledOnOpenChange,
}: {
  onAdd: (meal: Meal) => Promise<boolean>
  /** Optional when the dialog is driven via the controlled `open` API below. */
  trigger?: React.ReactNode
  defaultMealType?: MealType
  /** Controlled open API — when provided, overrides the internal open state. */
  open?: boolean
  onOpenChange?: (open: boolean) => void
}) {
  const [internalOpen, setInternalOpen] = React.useState(false)
  const isControlled = controlledOpen !== undefined
  const open = isControlled ? controlledOpen : internalOpen
  const setOpen = React.useCallback(
    (next: boolean) => {
      if (isControlled) controlledOnOpenChange?.(next)
      else setInternalOpen(next)
    },
    [isControlled, controlledOnOpenChange]
  )
  const [form, setForm] = React.useState(emptyForm)
  const [status, setStatus] = React.useState<MorphStatus>("idle")

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

  // Prefill the section on open / reset on close. Runs for both the controlled
  // and uncontrolled paths (Radix only fires onOpenChange on its own
  // interactions, not when `open` is flipped externally).
  React.useEffect(() => {
    if (open) {
      setForm((f) => ({ ...f, mealType: defaultMealType ?? suggestedMealType() }))
    } else {
      setForm(emptyForm)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, defaultMealType])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (status !== "idle") return
    if (!form.name.trim() || !form.calories) return

    setStatus("loading")
    const ok = await onAdd({
      id: crypto.randomUUID(),
      name: form.name.trim(),
      mealType: form.mealType,
      servingSize: form.servingSize.trim() || undefined,
      calories: Number(form.calories) || 0,
      protein: Number(form.protein) || 0,
      carbs: Number(form.carbs) || 0,
      fat: Number(form.fat) || 0,
      loggedAt: new Date(),
    })
    setStatus(ok ? "success" : "error")

    setTimeout(() => {
      setStatus("idle")
      if (ok) {
        setForm(emptyForm)
        setOpen(false)
      }
    }, 1300)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (status !== "idle") return
        setOpen(next)
      }}
    >
      {trigger && <DialogTrigger asChild>{trigger}</DialogTrigger>}
      <DialogContent className="sm:max-w-md">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Add a meal</DialogTitle>
            <DialogDescription>
              Log what you ate and its nutrition facts. Macros are optional
              but help your daily rings stay accurate.
            </DialogDescription>
          </DialogHeader>

          <FieldGroup className="mt-4">
            <Field>
              <FieldLabel htmlFor="meal-name">Meal name</FieldLabel>
              <Input
                id="meal-name"
                placeholder="Grilled chicken bowl"
                value={form.name}
                onChange={(e) => update("name", e.target.value)}
                required
                autoFocus
              />
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="meal-type">Type</FieldLabel>
                <Select
                  value={form.mealType}
                  onValueChange={(v) => update("mealType", v as MealType)}
                >
                  <SelectTrigger id="meal-type" className="w-full">
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

              <Field>
                <FieldLabel htmlFor="serving-size">Serving size</FieldLabel>
                <Input
                  id="serving-size"
                  placeholder="1 bowl"
                  value={form.servingSize}
                  onChange={(e) => update("servingSize", e.target.value)}
                />
              </Field>
            </div>

            <Field>
              <FieldLabel htmlFor="calories">Calories</FieldLabel>
              <Input
                id="calories"
                type="number"
                inputMode="numeric"
                min={0}
                placeholder="620"
                value={form.calories}
                onChange={(e) => update("calories", e.target.value)}
                required
              />
            </Field>

            <div className="grid grid-cols-3 gap-4">
              <Field>
                <FieldLabel htmlFor="protein">Protein (g)</FieldLabel>
                <Input
                  id="protein"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="45"
                  value={form.protein}
                  onChange={(e) => update("protein", e.target.value)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="carbs">Carbs (g)</FieldLabel>
                <Input
                  id="carbs"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="60"
                  value={form.carbs}
                  onChange={(e) => update("carbs", e.target.value)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="fat">Fat (g)</FieldLabel>
                <Input
                  id="fat"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="18"
                  value={form.fat}
                  onChange={(e) => update("fat", e.target.value)}
                />
              </Field>
            </div>
          </FieldGroup>

          <DialogFooter className="mt-6">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={status !== "idle"}
            >
              Cancel
            </Button>
            <MorphButton
              type="submit"
              status={status}
              onClick={() => {}}
              idleLabel="Add meal"
              loadingLabel="Adding…"
              successLabel="Added"
            />
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
