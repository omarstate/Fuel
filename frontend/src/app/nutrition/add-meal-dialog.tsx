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
import { mealTypeLabel, type Meal, type MealType } from "@/app/nutrition/types"

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
}: {
  onAdd: (meal: Meal) => Promise<boolean>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = React.useState(false)
  const [form, setForm] = React.useState(emptyForm)
  const [status, setStatus] = React.useState<MorphStatus>("idle")

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

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
        if (!next) setForm(emptyForm)
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
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
