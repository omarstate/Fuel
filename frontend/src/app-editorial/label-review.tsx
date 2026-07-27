import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"
import { MACROS, type Review } from "@/app-editorial/label-portion"

const confidenceTone: Record<NonNullable<Review["confidence"]>, string> = {
  high: "bg-[var(--accent-tint)] text-[var(--accent-ink)]",
  medium: "bg-muted text-muted-foreground",
  low: "bg-[color-mix(in_oklab,#c85a3c_16%,transparent)] text-[#c85a3c]",
}

const SERVING_CHIPS = [
  { label: "½", value: 0.5 },
  { label: "1", value: 1 },
  { label: "2", value: 2 },
] as const
const GRAM_CHIPS = [50, 100, 150, 250] as const

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-md px-2 py-1 font-mono text-[0.65rem] uppercase tracking-[0.08em] transition-colors",
        active
          ? "bg-[var(--accent-tint)] text-[var(--accent-ink)]"
          : "bg-muted text-muted-foreground hover:text-foreground"
      )}
    >
      {children}
    </button>
  )
}

/** Editable review card shared by the photo-label and barcode flows: name,
 * a "how much did you eat?" portion control that rescales the totals, the four
 * macro fields, and any note (source attribution or a warning). The parent owns
 * the `Review` state and passes `onPatch` for direct field edits and `onPortion`
 * for the scaler. */
export function LabelReview({
  review,
  onPatch,
  onPortion,
}: {
  review: Review
  onPatch: (p: Partial<Review>) => void
  onPortion: (p: Partial<Pick<Review, "grams" | "servings">>) => void
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-3">
      <div className="flex items-start justify-between gap-2">
        <Input
          value={review.name}
          onChange={(e) => onPatch({ name: e.target.value })}
          placeholder="Name this product"
          className="h-8 flex-1 font-medium"
        />
        {review.confidence && (
          <span
            className={cn(
              "inline-flex items-center rounded-md px-1.5 py-0.5 font-mono text-[0.6rem] uppercase tracking-[0.1em]",
              confidenceTone[review.confidence]
            )}
          >
            {review.confidence}
          </span>
        )}
      </div>

      {/* Portion control — drives the totals below. */}
      <div className="mt-3 rounded-lg bg-muted/50 p-2.5">
        <p className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
          How much did you eat?
        </p>

        {review.servingGrams !== null ? (
          // Grams eaten, with serving-size shortcut chips.
          <div className="mt-2">
            <div className="flex flex-wrap items-end gap-3">
              <label className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Grams eaten
                </span>
                <Input
                  type="number"
                  inputMode="numeric"
                  min={0}
                  value={review.grams}
                  onChange={(e) => onPortion({ grams: e.target.value })}
                  className="h-8 w-28"
                />
              </label>
              <div className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Servings
                </span>
                <div className="flex gap-1.5">
                  {SERVING_CHIPS.map((c) => (
                    <Chip
                      key={c.value}
                      active={Number(review.servings) === c.value}
                      onClick={() => onPortion({ servings: String(c.value) })}
                    >
                      {c.label}
                    </Chip>
                  ))}
                </div>
              </div>
            </div>
            <p className="mt-2 text-[0.7rem] leading-tight text-muted-foreground">
              1 serving = {review.servingGrams} g
              {review.servingSize ? ` · ${review.servingSize}` : ""}.
            </p>
          </div>
        ) : review.basis === "per_100g" ? (
          // Per 100 g, no printed serving size — grams input + gram presets.
          <div className="mt-2">
            <div className="flex flex-wrap items-end gap-3">
              <label className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Grams eaten
                </span>
                <Input
                  type="number"
                  inputMode="numeric"
                  min={0}
                  value={review.grams}
                  onChange={(e) => onPortion({ grams: e.target.value })}
                  className="h-8 w-28"
                />
              </label>
              <div className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Quick
                </span>
                <div className="flex gap-1.5">
                  {GRAM_CHIPS.map((g) => (
                    <Chip
                      key={g}
                      active={Number(review.grams) === g}
                      onClick={() => onPortion({ grams: String(g) })}
                    >
                      {`${g} g`}
                    </Chip>
                  ))}
                </div>
              </div>
            </div>
            <p className="mt-2 text-[0.7rem] leading-tight text-muted-foreground">
              Values are per 100 g.
            </p>
          </div>
        ) : (
          // Per serving, no printed size — servings only.
          <div className="mt-2">
            <div className="flex flex-wrap items-end gap-3">
              <label className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Servings
                </span>
                <Input
                  type="number"
                  inputMode="decimal"
                  min={0}
                  step={0.5}
                  value={review.servings}
                  onChange={(e) => onPortion({ servings: e.target.value })}
                  className="h-8 w-28"
                />
              </label>
              <div className="flex flex-col gap-1">
                <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
                  Quick
                </span>
                <div className="flex gap-1.5">
                  {SERVING_CHIPS.map((c) => (
                    <Chip
                      key={c.value}
                      active={Number(review.servings) === c.value}
                      onClick={() => onPortion({ servings: String(c.value) })}
                    >
                      {c.label}
                    </Chip>
                  ))}
                </div>
              </div>
            </div>
            <p className="mt-2 text-[0.7rem] leading-tight text-muted-foreground">
              {review.servingSize
                ? `Values are per serving · ${review.servingSize}.`
                : "This label doesn't say how big one serving is — set servings as best you can."}
            </p>
          </div>
        )}
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
        {MACROS.map((k) => (
          <label key={k} className="flex flex-col gap-1">
            <span className="font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muted-foreground">
              {k === "calories" ? "kcal" : `${k.slice(0, 1).toUpperCase()} (g)`}
            </span>
            <Input
              type="number"
              inputMode="numeric"
              min={0}
              value={review[k]}
              onChange={(e) => onPatch({ [k]: e.target.value } as Partial<Review>)}
              className="h-8"
            />
          </label>
        ))}
      </div>

      {review.note && (
        <p className={cn("mt-2 text-xs", review.ok ? "text-muted-foreground" : "text-destructive")}>
          {review.note}
        </p>
      )}
    </div>
  )
}
