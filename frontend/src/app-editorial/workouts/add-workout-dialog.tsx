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
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { getWorkoutCategories, type WorkoutCategory } from "@/lib/api"

const emptyForm = {
  name: "",
  description: "",
  categoryIds: [] as string[],
  primaryMuscle: "",
  equipment: "",
  targetSets: "",
  targetReps: "",
}

export function AddWorkoutDialog({
  onCreate,
  trigger,
}: {
  onCreate: (input: {
    name: string
    description?: string
    categoryIds: string[]
    primaryMuscle?: string
    equipment?: string
    targetSets?: number
    targetReps?: string
  }) => Promise<unknown>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = React.useState(false)
  const [form, setForm] = React.useState(emptyForm)
  const [categories, setCategories] = React.useState<WorkoutCategory[]>([])
  const [categoriesLoading, setCategoriesLoading] = React.useState(false)
  const [submitting, setSubmitting] = React.useState(false)

  React.useEffect(() => {
    if (!open) return
    let active = true
    setCategoriesLoading(true)
    getWorkoutCategories()
      .then((cats) => {
        if (!active) return
        setCategories(cats)
      })
      .catch(() => {
        if (!active) return
        toast.error("Couldn't load workout types.")
      })
      .finally(() => {
        if (active) setCategoriesLoading(false)
      })
    return () => {
      active = false
    }
  }, [open])

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!form.name.trim() || form.categoryIds.length === 0) return

    setSubmitting(true)
    try {
      await onCreate({
        name: form.name.trim(),
        description: form.description.trim() || undefined,
        categoryIds: form.categoryIds,
        primaryMuscle: form.primaryMuscle.trim() || undefined,
        equipment: form.equipment.trim() || undefined,
        targetSets: form.targetSets ? Number(form.targetSets) || undefined : undefined,
        targetReps: form.targetReps.trim() || undefined,
      })
      toast.success(`${form.name.trim()} added to the library`)
      setForm(emptyForm)
      setOpen(false)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't add that workout.")
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) setForm(emptyForm)
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Add a workout to the library</DialogTitle>
            <DialogDescription>
              Contribute a workout to the shared catalog. Pick every type it belongs to.
            </DialogDescription>
          </DialogHeader>

          <FieldGroup className="mt-4">
            <Field>
              <FieldLabel htmlFor="workout-name">Workout name</FieldLabel>
              <Input
                id="workout-name"
                placeholder="Bench Press"
                value={form.name}
                onChange={(e) => update("name", e.target.value)}
                required
                autoFocus
              />
            </Field>

            <Field>
              <FieldLabel>Types</FieldLabel>
              <ToggleGroup
                type="multiple"
                variant="outline"
                size="sm"
                value={form.categoryIds}
                onValueChange={(value) => update("categoryIds", value)}
                className="flex flex-wrap justify-start"
              >
                {categoriesLoading ? (
                  <span className="text-sm text-muted-foreground">Loading…</span>
                ) : (
                  categories.map((c) => (
                    <ToggleGroupItem key={c.id} value={c.id} aria-label={c.name}>
                      {c.name}
                    </ToggleGroupItem>
                  ))
                )}
              </ToggleGroup>
              {form.categoryIds.length === 0 && (
                <p className="text-xs text-muted-foreground">Pick at least one type.</p>
              )}
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="workout-primary-muscle">Primary muscle</FieldLabel>
                <Input
                  id="workout-primary-muscle"
                  placeholder="Chest"
                  value={form.primaryMuscle}
                  onChange={(e) => update("primaryMuscle", e.target.value)}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="workout-equipment">Equipment</FieldLabel>
                <Input
                  id="workout-equipment"
                  placeholder="Barbell"
                  value={form.equipment}
                  onChange={(e) => update("equipment", e.target.value)}
                />
              </Field>
            </div>

            <Field>
              <FieldLabel htmlFor="workout-description">
                Description <span className="text-muted-foreground">(optional)</span>
              </FieldLabel>
              <Input
                id="workout-description"
                placeholder="How it's performed, cues…"
                value={form.description}
                onChange={(e) => update("description", e.target.value)}
              />
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="workout-target-sets">Target sets</FieldLabel>
                <Input
                  id="workout-target-sets"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  placeholder="4"
                  value={form.targetSets}
                  onChange={(e) => update("targetSets", e.target.value)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="workout-target-reps">Target reps</FieldLabel>
                <Input
                  id="workout-target-reps"
                  placeholder="8-12"
                  value={form.targetReps}
                  onChange={(e) => update("targetReps", e.target.value)}
                />
              </Field>
            </div>
          </FieldGroup>

          <DialogFooter className="mt-6">
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting || form.categoryIds.length === 0}>
              {submitting ? "Adding…" : "Add workout"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
