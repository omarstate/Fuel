import { KCAL_PER_KG, type Direction } from "@/lib/nutrition"
import type { WeekDay } from "@/app-editorial/use-week-meals"
import { useI18n, type I18nContextValue } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/en"

const DAY_LABEL_KEYS: MessageKey[] = [
  "week.mon",
  "week.tue",
  "week.wed",
  "week.thu",
  "week.fri",
  "week.sat",
  "week.sun",
]

/** A day counts as "on target" if it lands within this fraction of the goal. */
const TARGET_BAND = 0.1
/** Goal maps to this fraction of the chart height, leaving headroom for
 * over-goal days to visibly clear the goal line. */
const GOAL_LINE_FRAC = 0.72

type Outcome = "under" | "onTarget" | "over"

function outcomeFor(calories: number, goal: number): Outcome {
  if (calories > goal * (1 + TARGET_BAND)) return "over"
  if (calories < goal * (1 - TARGET_BAND)) return "under"
  return "onTarget"
}

const OVER_COLOR = "#c85a3c"

function barColor(outcome: Outcome, accent: string): string {
  if (outcome === "onTarget") return accent
  if (outcome === "over") return OVER_COLOR
  return "color-mix(in oklab, var(--foreground) 20%, transparent)"
}

function formatSigned(n: number, formatNumber: I18nContextValue["formatNumber"]): string {
  const rounded = Math.round(n)
  const sign = rounded > 0 ? "+" : rounded < 0 ? "−" : ""
  return `${sign}${formatNumber(Math.abs(rounded))}`
}

/** Turns the week's net calorie delta into a one-line read that respects the
 * user's goal direction — a deficit is progress when cutting, a shortfall when
 * bulking, and drift either way when maintaining. */
function netSummary(net: number, direction: Direction, i18n: I18nContextValue) {
  const { t, formatNumber } = i18n
  const kg = Math.abs(net) / KCAL_PER_KG
  const kgLabel =
    kg < 0.1 ? t("week.underTenthKg") : t("week.approxKg", { value: formatNumber(kg, { maximumFractionDigits: 1, minimumFractionDigits: 1 }) })

  if (direction === "maintain") {
    const onTrack = Math.abs(net) < KCAL_PER_KG * 0.15
    if (onTrack) return { onTrack, text: t("week.holdingSteady") }
    return {
      onTrack,
      text: `${net < 0 ? t("week.underMaintenance") : t("week.overMaintenance")} · ${kgLabel}`,
    }
  }

  if (direction === "cut") {
    if (net < 0) return { onTrack: true, text: t("week.onTrackLose", { value: kgLabel }) }
    return { onTrack: false, text: t("week.surplusVsCut", { value: kgLabel }) }
  }

  // bulk
  if (net > 0) return { onTrack: true, text: t("week.onTrackGain", { value: kgLabel }) }
  return { onTrack: false, text: t("week.deficitVsBulk", { value: kgLabel }) }
}

export function WeekChart({
  accent,
  days,
  goal,
  direction = "maintain",
  loading = false,
}: {
  accent: string
  days: WeekDay[]
  goal: number
  direction?: Direction
  loading?: boolean
}) {
  const tracked = days.filter((d) => d.logged && !d.isFuture)
  const maxCalories = Math.max(0, ...tracked.map((d) => d.calories))
  // Scale so the goal sits at GOAL_LINE_FRAC of the height, but grow the axis
  // if any day overshoots so its bar still fits with the goal line below it.
  const scaleMax = Math.max(goal / GOAL_LINE_FRAC, maxCalories, 1)
  const goalBottomPct = (goal / scaleMax) * 100

  const daysOnTarget = tracked.filter((d) => outcomeFor(d.calories, goal) === "onTarget").length
  const avg = tracked.length
    ? Math.round(tracked.reduce((s, d) => s + d.calories, 0) / tracked.length)
    : 0
  const net = tracked.reduce((s, d) => s + (d.calories - goal), 0)
  const i18n = useI18n()
  const { t, formatNumber } = i18n
  const summary = netSummary(net, direction, i18n)
  const hasData = tracked.length > 0

  return (
    <div className="rounded-xl border border-border bg-card p-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
            {t("week.thisWeek")}
          </div>
          <div className="mt-1 text-sm text-foreground">{t("week.caloriesVsGoal")}</div>
        </div>
        <div className="flex items-center gap-3 font-mono text-[0.65rem] text-muted-foreground">
          <span className="flex items-center gap-1.5">
            <span className="size-2 rounded-full" style={{ backgroundColor: accent }} />
            {t("week.onTarget")}
          </span>
          <span className="flex items-center gap-1.5">
            <span className="size-2 rounded-full" style={{ backgroundColor: OVER_COLOR }} />
            {t("week.over")}
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-px w-3 border-t border-dashed border-muted-foreground" />
            {t("week.goal")}
          </span>
        </div>
      </div>

      <div className="relative mt-6 flex h-32 items-end gap-3">
        {/* goal line, positioned to match the bar scale */}
        <div
          className="pointer-events-none absolute inset-x-0 border-t border-dashed border-muted-foreground/50"
          style={{ bottom: `${goalBottomPct}%` }}
        />
        {days.map((d) => {
          const outcome = outcomeFor(d.calories, goal)
          const barPct = d.logged ? Math.max((d.calories / scaleMax) * 100, 2) : 0
          return (
            <div key={d.index} className="flex flex-1 flex-col items-center gap-2">
              <div className="relative flex h-full w-full items-end justify-center">
                {d.logged ? (
                  <div
                    className={`w-full max-w-9 rounded-t-sm transition-[height] duration-500 ${
                      d.isToday ? "ring-2 ring-inset ring-foreground/15" : ""
                    }`}
                    style={{ height: `${barPct}%`, backgroundColor: barColor(outcome, accent) }}
                  />
                ) : (
                  // Not logged — a faint hatched stub, clearly distinct from a
                  // real low-calorie day so a skipped day doesn't read as a deficit.
                  <div
                    className="h-1.5 w-full max-w-9 rounded-t-sm"
                    style={{
                      backgroundImage: d.isFuture
                        ? "none"
                        : "repeating-linear-gradient(45deg, color-mix(in oklab, var(--foreground) 14%, transparent) 0 2px, transparent 2px 4px)",
                      backgroundColor: d.isFuture
                        ? "color-mix(in oklab, var(--foreground) 5%, transparent)"
                        : "transparent",
                    }}
                  />
                )}
              </div>
              <span
                className={`font-mono text-[0.65rem] ${
                  d.isToday
                    ? "font-semibold text-foreground"
                    : d.isFuture
                      ? "text-muted-foreground/50"
                      : "text-muted-foreground"
                }`}
              >
                {t(DAY_LABEL_KEYS[d.index])}
              </span>
            </div>
          )
        })}
      </div>

      {/* Weekly scoreboard */}
      <div className="mt-6 grid grid-cols-3 gap-4 border-t border-border pt-4">
        <Stat
          label={t("week.onTarget")}
          value={hasData ? `${formatNumber(daysOnTarget)}/${formatNumber(tracked.length)}` : "—"}
          hint={t("week.days")}
        />
        <Stat
          label={t("week.dailyAvg")}
          value={hasData ? formatNumber(avg) : "—"}
          hint={t("week.ofKcal", { value: formatNumber(goal) })}
        />
        <Stat
          label={t("week.netVsGoal")}
          value={hasData ? formatSigned(net, formatNumber) : "—"}
          hint={t("week.kcalThisWeek")}
        />
      </div>

      {hasData && !loading && (
        <div
          className={`mt-3 inline-flex items-center gap-2 rounded-md px-2.5 py-1 text-xs font-medium ${
            summary.onTrack
              ? "bg-[var(--accent-tint)] text-[var(--accent-ink)]"
              : "bg-[color-mix(in_oklab,#c85a3c_14%,transparent)] text-[#c85a3c]"
          }`}
        >
          {summary.text}
        </div>
      )}
    </div>
  )
}

function Stat({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div>
      <div className="font-mono text-[0.6rem] uppercase tracking-[0.14em] text-muted-foreground">
        {label}
      </div>
      <div className="mt-1 font-mono text-lg font-semibold leading-none text-foreground">
        {value}
      </div>
      <div className="mt-1 text-[0.7rem] text-muted-foreground">{hint}</div>
    </div>
  )
}
