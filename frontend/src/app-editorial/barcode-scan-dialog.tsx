import * as React from "react"
import { toast } from "sonner"
import { Barcode, ArrowLeft, ScanLine, PackageX, Camera } from "lucide-react"
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
import { useBarcodeScanner } from "@/app-editorial/use-barcode-scanner"
import { portionFactor, scaled, toReview, type Review } from "@/app-editorial/label-portion"
import { LabelReview } from "@/app-editorial/label-review"
import { lookupBarcode } from "@/lib/api"
import { mealTypeLabel, suggestedMealType, type Meal, type MealType } from "@/app/nutrition/types"

const isBarcodeLike = (s: string) => /^\d{8,14}$/.test(s.trim())

export function BarcodeScanDialog({
  onAdd,
  trigger,
}: {
  onAdd: (meal: Meal) => Promise<boolean>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = React.useState(false)
  const [step, setStep] = React.useState<"scan" | "review">("scan")
  const [scannedCode, setScannedCode] = React.useState<string | null>(null)
  const [looking, setLooking] = React.useState(false)
  const [notFound, setNotFound] = React.useState<string | null>(null)
  const [manualCode, setManualCode] = React.useState("")
  const [mealType, setMealType] = React.useState<MealType>(suggestedMealType())
  const [review, setReview] = React.useState<Review | null>(null)
  const [saveStatus, setSaveStatus] = React.useState<MorphStatus>("idle")

  // Camera runs only while scanning and idle (paused during lookup / after a hit).
  const scannerActive = open && step === "scan" && !scannedCode && !looking && !notFound

  const handleLookup = React.useCallback(async (code: string) => {
    setScannedCode(code)
    setLooking(true)
    setNotFound(null)
    try {
      const product = await lookupBarcode(code)
      if (!product.found) {
        setNotFound(code)
        return
      }
      setReview(toReview(product))
      setStep("review")
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Barcode lookup failed.")
      setScannedCode(null) // resume scanning
    } finally {
      setLooking(false)
    }
  }, [])

  const {
    videoRef,
    error: cameraError,
    needsTap,
    startCamera,
  } = useBarcodeScanner({
    active: scannerActive,
    onDetect: (code) => {
      if (!scannedCode && !looking) void handleLookup(code)
    },
  })

  function reset() {
    setStep("scan")
    setScannedCode(null)
    setLooking(false)
    setNotFound(null)
    setManualCode("")
    setMealType(suggestedMealType())
    setReview(null)
    setSaveStatus("idle")
  }

  function scanAgain() {
    setScannedCode(null)
    setNotFound(null)
  }

  function patch(p: Partial<Review>) {
    setReview((prev) => (prev ? { ...prev, ...p } : prev))
  }

  function setPortion(p: Partial<Pick<Review, "grams" | "servings">>) {
    setReview((prev) => {
      if (!prev) return prev
      const next = { ...prev, ...p }
      return { ...next, ...scaled(next.base, portionFactor(next)) }
    })
  }

  function handleManual() {
    const code = manualCode.trim()
    if (!isBarcodeLike(code)) {
      toast.error("Enter a valid barcode (8–14 digits).")
      return
    }
    void handleLookup(code)
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
    toast.success("Logged from barcode.")
    setTimeout(() => {
      setOpen(false)
      reset()
    }, 1200)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (looking || saveStatus === "loading") return
        setOpen(next)
        if (!next) reset()
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        {step === "scan" ? (
          <div>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Barcode className="size-4 text-[var(--accent-ink)]" />
                Scan a barcode
              </DialogTitle>
              <DialogDescription>
                Point your camera at the product barcode. Nutrition data comes from
                Open Food Facts.
              </DialogDescription>
            </DialogHeader>

            <FieldGroup className="mt-4">
              {notFound ? (
                <div className="flex aspect-[4/3] w-full flex-col items-center justify-center gap-3 rounded-xl border border-dashed border-border bg-muted/40 p-4 text-center">
                  <span className="grid size-11 place-items-center rounded-xl bg-muted text-muted-foreground">
                    <PackageX className="size-5" />
                  </span>
                  <div>
                    <div className="font-medium text-foreground">Not in the database</div>
                    <p className="mt-1 text-sm text-muted-foreground">
                      No product for barcode {notFound}. Snap its nutrition label with the
                      Photo button instead, or scan another.
                    </p>
                  </div>
                  <Button type="button" variant="outline" size="sm" onClick={scanAgain}>
                    Scan again
                  </Button>
                </div>
              ) : cameraError ? (
                <div className="flex aspect-[4/3] w-full flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border bg-muted/40 p-4 text-center text-sm text-muted-foreground">
                  <ScanLine className="size-6" />
                  {cameraError}
                </div>
              ) : (
                <div className="relative aspect-[4/3] w-full overflow-hidden rounded-xl border border-border bg-black">
                  <video
                    ref={videoRef}
                    className="size-full object-cover"
                    muted
                    playsInline
                  />
                  {/* scan reticle */}
                  <div className="pointer-events-none absolute inset-0 grid place-items-center">
                    <div className="h-24 w-4/5 rounded-lg border-2 border-white/80 shadow-[0_0_0_100vmax_rgba(0,0,0,0.25)]" />
                  </div>
                  {needsTap && (
                    <button
                      type="button"
                      onClick={startCamera}
                      className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-black/60 text-sm font-medium text-white"
                    >
                      <span className="grid size-12 place-items-center rounded-full bg-white/15">
                        <Camera className="size-6" />
                      </span>
                      Tap to start camera
                    </button>
                  )}
                  {looking && (
                    <div className="absolute inset-0 grid place-items-center bg-black/50 text-sm font-medium text-white">
                      Looking up…
                    </div>
                  )}
                </div>
              )}

              <Field>
                <FieldLabel htmlFor="barcode-manual">Or enter the barcode</FieldLabel>
                <div className="flex gap-2">
                  <Input
                    id="barcode-manual"
                    inputMode="numeric"
                    placeholder="6223001360049"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        e.preventDefault()
                        handleManual()
                      }
                    }}
                    disabled={looking}
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={handleManual}
                    disabled={looking || !manualCode.trim()}
                  >
                    Look up
                  </Button>
                </div>
              </Field>

              <Field>
                <FieldLabel htmlFor="barcode-meal-type">Meal</FieldLabel>
                <Select value={mealType} onValueChange={(v) => setMealType(v as MealType)}>
                  <SelectTrigger id="barcode-meal-type" className="w-full">
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
                disabled={looking}
                className="h-11 w-full sm:h-9 sm:w-auto"
              >
                Cancel
              </Button>
            </DialogFooter>
          </div>
        ) : (
          review && (
            <div>
              <DialogHeader>
                <DialogTitle>Review product</DialogTitle>
                <DialogDescription>
                  {review.ok
                    ? "Set how much you ate and check the totals before logging."
                    : "This product has no saved nutrition data — enter it, or snap the label instead."}
                </DialogDescription>
              </DialogHeader>

              <div className="mt-4 flex max-h-[56vh] flex-col gap-3 overflow-y-auto pr-1">
                <LabelReview review={review} onPatch={patch} onPortion={setPortion} />
              </div>

              <DialogFooter className="mt-6">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setStep("scan")
                    scanAgain()
                  }}
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
