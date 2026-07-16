import * as React from "react"
import { toast } from "sonner"
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
  getCategories,
  updateCatalogMeal,
  type Category,
  type CatalogMeal,
  type CreateCatalogMealInput,
} from "@/lib/api"

const emptyForm = {
  name: "",
  description: "",
  categoryId: "",
  servingSize: "",
  calories: "",
  protein: "",
  carbs: "",
  fat: "",
}

function mealToForm(meal: CatalogMeal): typeof emptyForm {
  return {
    name: meal.name,
    description: meal.description ?? "",
    categoryId: meal.category?.id ?? "",
    servingSize: meal.servingSize ?? "",
    calories: String(meal.calories ?? ""),
    protein: String(meal.protein ?? ""),
    carbs: String(meal.carbs ?? ""),
    fat: String(meal.fat ?? ""),
  }
}

export function AddCatalogMealDialog({
  onCreate,
  meal,
  onSaved,
  trigger,
}: {
  /** Required for create mode; ignored when `meal` is provided. */
  onCreate?: (input: CreateCatalogMealInput) => Promise<unknown>
  /** When provided, the dialog edits this meal instead of creating a new one. */
  meal?: CatalogMeal
  /** Called after a successful create or edit (in addition to the toast). */
  onSaved?: () => void
  trigger: React.ReactNode
}) {
  const isEdit = !!meal
  const [open, setOpen] = React.useState(false)
  const [form, setForm] = React.useState(emptyForm)
  const [categories, setCategories] = React.useState<Category[]>([])
  const [categoriesLoading, setCategoriesLoading] = React.useState(false)
  const [status, setStatus] = React.useState<MorphStatus>("idle")

  React.useEffect(() => {
    if (!open) return
    let active = true
    setCategoriesLoading(true)
    getCategories()
      .then((cats) => {
        if (!active) return
        setCategories(cats)
      })
      .catch(() => {
        if (!active) return
        toast.error("Couldn't load categories.")
      })
      .finally(() => {
        if (active) setCategoriesLoading(false)
      })
    return () => {
      active = false
    }
  }, [open])

  React.useEffect(() => {
    if (!open) return
    setForm(meal ? mealToForm(meal) : emptyForm)
    // Re-prefill whenever the dialog opens for a given meal (or resets for create).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, meal])

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (status !== "idle") return
    if (!form.name.trim() || !form.categoryId || !form.calories) return

    const payload: CreateCatalogMealInput = {
      name: form.name.trim(),
      description: form.description.trim() || undefined,
      categoryId: form.categoryId,
      servingSize: form.servingSize.trim() || undefined,
      calories: Number(form.calories) || 0,
      protein: Number(form.protein) || 0,
      carbs: Number(form.carbs) || 0,
      fat: Number(form.fat) || 0,
    }

    setStatus("loading")
    try {
      if (isEdit && meal) {
        await updateCatalogMeal(meal.id, payload)
      } else if (onCreate) {
        await onCreate(payload)
      }
      setStatus("success")
      setTimeout(() => {
        setStatus("idle")
        setOpen(false)
        onSaved?.()
      }, 1300)
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : `Couldn't ${isEdit ? "update" : "add"} that meal.`
      )
      setStatus("error")
      setTimeout(() => setStatus("idle"), 1300)
    }
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
            <DialogTitle>{isEdit ? "Edit meal" : "Add a meal to the library"}</DialogTitle>
            <DialogDescription>
              {isEdit
                ? "Update this meal's details in the shared catalog."
                : "Contribute a meal to the shared catalog so anyone can log it later."}
            </DialogDescription>
          </DialogHeader>

          <FieldGroup className="mt-4">
            <Field>
              <FieldLabel htmlFor="catalog-meal-name">Meal name</FieldLabel>
              <Input
                id="catalog-meal-name"
                placeholder="Grilled chicken bowl"
                value={form.name}
                onChange={(e) => update("name", e.target.value)}
                required
                autoFocus
              />
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="catalog-meal-category">Category</FieldLabel>
                <Select
                  value={form.categoryId}
                  onValueChange={(v) => update("categoryId", v)}
                >
                  <SelectTrigger id="catalog-meal-category" className="w-full">
                    <SelectValue
                      placeholder={categoriesLoading ? "Loading…" : "Choose a category"}
                    />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectGroup>
                      {categories.map((c) => (
                        <SelectItem key={c.id} value={c.id}>
                          {c.name}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  </SelectContent>
                </Select>
              </Field>

              <Field>
                <FieldLabel htmlFor="catalog-meal-serving">Serving size</FieldLabel>
                <Input
                  id="catalog-meal-serving"
                  placeholder="1 bowl"
                  value={form.servingSize}
                  onChange={(e) => update("servingSize", e.target.value)}
                />
              </Field>
            </div>

            <Field>
              <FieldLabel htmlFor="catalog-meal-description">
                Description <span className="text-muted-foreground">(optional)</span>
              </FieldLabel>
              <Input
                id="catalog-meal-description"
                placeholder="What's in it, how it's made…"
                value={form.description}
                onChange={(e) => update("description", e.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="catalog-meal-calories">Calories</FieldLabel>
              <Input
                id="catalog-meal-calories"
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
                <FieldLabel htmlFor="catalog-meal-protein">Protein (g)</FieldLabel>
                <Input
                  id="catalog-meal-protein"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="45"
                  value={form.protein}
                  onChange={(e) => update("protein", e.target.value)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="catalog-meal-carbs">Carbs (g)</FieldLabel>
                <Input
                  id="catalog-meal-carbs"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="60"
                  value={form.carbs}
                  onChange={(e) => update("carbs", e.target.value)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="catalog-meal-fat">Fat (g)</FieldLabel>
                <Input
                  id="catalog-meal-fat"
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
              className="h-11 w-full sm:h-9 sm:w-auto"
            >
              Cancel
            </Button>
            <MorphButton
              type="submit"
              status={status}
              onClick={() => {}}
              idleLabel={isEdit ? "Save changes" : "Add meal"}
              loadingLabel={isEdit ? "Saving…" : "Adding…"}
              successLabel={isEdit ? "Saved" : "Added"}
              className="w-full sm:w-auto"
            />
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
