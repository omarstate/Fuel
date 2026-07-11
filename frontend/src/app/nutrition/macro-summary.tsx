const GOAL_CALORIES = 2200

export function MacroSummary({
  accent,
  calories,
  protein,
  carbs,
  fat,
}: {
  accent: string
  calories: number
  protein: number
  carbs: number
  fat: number
}) {
  const pct = Math.min((calories / GOAL_CALORIES) * 100, 100)

  return (
    <div className="flex items-center gap-6 rounded-3xl border border-bone/10 bg-char-2 p-6">
      <div
        className="relative flex size-24 shrink-0 items-center justify-center rounded-full"
        style={{
          background: `conic-gradient(${accent} ${pct}%, color-mix(in oklab, ${accent} 15%, transparent) 0)`,
        }}
      >
        <div className="absolute inset-2 rounded-full bg-char-2" />
        <div className="relative text-center">
          <div className="font-mono text-lg font-semibold text-bone">
            {calories}
          </div>
          <div className="text-[0.65rem] text-smoke">
            / {GOAL_CALORIES} kcal
          </div>
        </div>
      </div>

      <div className="flex flex-1 items-center justify-between gap-6 sm:pr-10">
        {[
          { label: "Protein", value: protein },
          { label: "Carbs", value: carbs },
          { label: "Fat", value: fat },
        ].map((m) => (
          <div key={m.label}>
            <div className="font-mono text-xl font-semibold text-bone">
              {m.value}
              <span className="text-sm text-smoke">g</span>
            </div>
            <div className="text-xs text-smoke">{m.label}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
