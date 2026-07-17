import * as React from "react"
import { toast } from "sonner"
import { Camera, ArrowLeft, RefreshCw, ImageUp } from "lucide-react"
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
import { compressImage } from "@/app-editorial/image-compress"
import { portionFactor, scaled, toReview, type Review } from "@/app-editorial/label-portion"
import { LabelReview } from "@/app-editorial/label-review"
import { extractMealPhoto } from "@/lib/api"
import { mealTypeLabel, suggestedMealType, type Meal, type MealType } from "@/app/nutrition/types"

export function PhotoLogDialog({
  onAdd,
  trigger,
}: {
  onAdd: (meal: Meal) => Promise<boolean>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = React.useState(false)
  const [step, setStep] = React.useState<"capture" | "review">("capture")
  const [preview, setPreview] = React.useState<string | null>(null)
  const [image, setImage] = React.useState<{ base64: string; mimeType: string } | null>(null)
  const [extracting, setExtracting] = React.useState(false)
  const [mealType, setMealType] = React.useState<MealType>(suggestedMealType())
  const [review, setReview] = React.useState<Review | null>(null)
  const [saveStatus, setSaveStatus] = React.useState<MorphStatus>("idle")
  const fileRef = React.useRef<HTMLInputElement>(null)

  function reset() {
    setStep("capture")
    setPreview(null)
    setImage(null)
    setExtracting(false)
    setMealType(suggestedMealType())
    setReview(null)
    setSaveStatus("idle")
    if (fileRef.current) fileRef.current.value = ""
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    try {
      const compressed = await compressImage(file)
      setPreview(compressed.dataUrl)
      setImage({ base64: compressed.base64, mimeType: compressed.mimeType })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't read that image.")
    }
  }

  async function handleExtract() {
    if (!image || extracting) return
    setExtracting(true)
    try {
      const result = await extractMealPhoto({ image: image.base64, mimeType: image.mimeType })
      setReview(toReview(result))
      setStep("review")
      if (!result.ok) {
        toast.error(result.note || "Couldn't read that label — retake it or enter the values.")
      }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't read that label.")
    } finally {
      setExtracting(false)
    }
  }

  function patch(p: Partial<Review>) {
    setReview((prev) => (prev ? { ...prev, ...p } : prev))
  }

  // Portion change → rescale the macro fields from the label's base values.
  function setPortion(p: Partial<Pick<Review, "grams" | "servings">>) {
    setReview((prev) => {
      if (!prev) return prev
      const next = { ...prev, ...p }
      return { ...next, ...scaled(next.base, portionFactor(next)) }
    })
  }

  async function handleSave() {
    if (!review || saveStatus !== "idle") return
    if (!review.name.trim()) {
      toast.error("Give it a name before logging.")
      return
    }
    if (review.calories === "") {
      toast.error("Add calories before logging.")
      return
    }
    setSaveStatus("loading")
    const meal: Meal = {
      id: crypto.randomUUID(),
      name: review.name.trim(),
      mealType,
      servingSize: review.servingSize.trim() || undefined,
      calories: Number(review.calories) || 0,
      protein: Number(review.protein) || 0,
      carbs: Number(review.carbs) || 0,
      fat: Number(review.fat) || 0,
      loggedAt: new Date(),
    }
    const ok = await onAdd(meal)
    if (!ok) {
      setSaveStatus("error")
      setTimeout(() => setSaveStatus("idle"), 1300)
      return
    }
    setSaveStatus("success")
    toast.success("Logged from label.")
    setTimeout(() => {
      setOpen(false)
      reset()
    }, 1200)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (extracting || saveStatus === "loading") return
        setOpen(next)
        if (!next) reset()
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        {step === "capture" ? (
          <div>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Camera className="size-4 text-[var(--accent-ink)]" />
                Snap a nutrition label
              </DialogTitle>
              <DialogDescription>
                Photograph the Nutrition Facts panel. We'll read the calories and macros
                off it — you review before it's logged.
              </DialogDescription>
            </DialogHeader>

            <input
              ref={fileRef}
              type="file"
              accept="image/*"
              capture="environment"
              className="sr-only"
              onChange={handleFile}
            />

            <FieldGroup className="mt-4">
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                disabled={extracting}
                className="group relative flex aspect-[4/3] w-full items-center justify-center overflow-hidden rounded-xl border border-dashed border-border bg-muted/40 transition-colors hover:border-[var(--accent-ink)] disabled:pointer-events-none"
              >
                {preview ? (
                  <>
                    <img
                      src={preview}
                      alt="Selected label"
                      className="size-full object-contain"
                    />
                    <span className="absolute bottom-2 right-2 inline-flex items-center gap-1 rounded-md bg-background/85 px-2 py-1 text-xs font-medium text-foreground shadow-sm">
                      <RefreshCw className="size-3" /> Retake
                    </span>
                  </>
                ) : (
                  <div className="flex flex-col items-center gap-2 text-muted-foreground">
                    <span className="grid size-11 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
                      <ImageUp className="size-5" />
                    </span>
                    <span className="text-sm">Tap to take a photo or choose one</span>
                  </div>
                )}
              </button>

              <Field>
                <FieldLabel htmlFor="photo-meal-type">Meal</FieldLabel>
                <Select value={mealType} onValueChange={(v) => setMealType(v as MealType)}>
                  <SelectTrigger id="photo-meal-type" className="w-full">
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
                disabled={extracting}
                className="h-11 w-full sm:h-9 sm:w-auto"
              >
                Cancel
              </Button>
              <MorphButton
                type="button"
                status={extracting ? "loading" : "idle"}
                onClick={handleExtract}
                idleIcon={Camera}
                idleLabel="Read label"
                loadingLabel="Reading…"
                disabled={!image}
                className="w-full sm:w-auto"
              />
            </DialogFooter>
          </div>
        ) : (
          review && (
            <div>
              <DialogHeader>
                <DialogTitle>Review label</DialogTitle>
                <DialogDescription>
                  {review.basis === "per_100g"
                    ? "Values were read per 100 g — set how much you ate and check the totals."
                    : "Set how many servings you had and check the totals."}
                </DialogDescription>
              </DialogHeader>

              <div className="mt-4 flex max-h-[56vh] flex-col gap-3 overflow-y-auto pr-1">
                <LabelReview review={review} onPatch={patch} onPortion={setPortion} />
              </div>

              <DialogFooter className="mt-6">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setStep("capture")}
                  disabled={saveStatus === "loading"}
                  className="h-11 w-full gap-2 sm:h-9 sm:w-auto"
                >
                  <ArrowLeft className="size-4" /> Back
                </Button>
                <MorphButton
                  type="button"
                  status={saveStatus}
                  onClick={handleSave}
                  idleLabel="Log meal"
                  loadingLabel="Logging…"
                  successLabel="Logged"
                  className="w-full sm:w-auto"
                />
              </DialogFooter>
            </div>
          )
        )}
      </DialogContent>
    </Dialog>
  )
}
