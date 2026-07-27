import * as React from "react"
import { motion } from "framer-motion"
import { Flame, Beef, Wheat, Droplet } from "lucide-react"
import { useI18n } from "@/lib/i18n"
import type { Targets } from "@/lib/nutrition"

/**
 * Dark "activity rings" hero for the Today page — inspired by the Google Fit
 * summary card. Two concentric rings (calories = green outer, protein = blue
 * inner), the two headline numbers stacked at the center, a legend naming each
 * ring, then a three-up stat strip for the remaining macros + kcal left.
 * Self-contained + dark-only; the light pages keep `TodayOverview`.
 */

const GREEN = "#4be08a" // calories ring
const BLUE = "#3f8dff" // protein ring + stat values
const OVER = "#ff7a59" // over-budget accent
const TRACK = "rgba(255,255,255,0.06)"

function Ring({
  radius,
  stroke,
  color,
  pct,
  delay,
}: {
  radius: number
  stroke: number
  color: string
  pct: number
  delay: number
}) {
  const circ = 2 * Math.PI * radius
  return (
    <g transform="rotate(-90 120 120)">
      <circle cx="120" cy="120" r={radius} fill="none" stroke={TRACK} strokeWidth={stroke} />
      <motion.circle
        cx="120"
        cy="120"
        r={radius}
        fill="none"
        stroke={color}
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circ}
        initial={{ strokeDashoffset: circ }}
        animate={{ strokeDashoffset: circ * (1 - pct) }}
        transition={{ duration: 1.1, delay, ease: [0.22, 1, 0.36, 1] }}
        style={{ filter: `drop-shadow(0 0 5px ${color}66)` }}
      />
    </g>
  )
}

function Legend({ color, icon: Icon, label, value }: {
  color: string
  icon: React.ComponentType<{ className?: string; style?: React.CSSProperties }>
  label: string
  value: string
}) {
  return (
    <div className="flex items-center gap-2">
      <Icon className="size-4 shrink-0" style={{ color }} />
      <div className="leading-tight">
        <div className="text-[0.8rem] font-medium text-white/85">{label}</div>
        <div className="text-[0.7rem] text-white/45">{value}</div>
      </div>
    </div>
  )
}

export function TodayRings({
  calories,
  protein,
  carbs,
  fat,
  goals,
}: {
  calories: number
  protein: number
  carbs: number
  fat: number
  goals: Targets
}) {
  const { t, formatNumber } = useI18n()

  const calPct = goals.calories > 0 ? Math.min(calories / goals.calories, 1) : 0
  const proPct = goals.protein > 0 ? Math.min(protein / goals.protein, 1) : 0
  const remaining = goals.calories - calories
  const over = remaining < 0

  const stats = [
    { icon: Wheat, value: carbs, unit: t("common.g"), label: t("macro.carbs"), color: BLUE },
    { icon: Droplet, value: fat, unit: t("common.g"), label: t("macro.fat"), color: BLUE },
    {
      icon: Flame,
      value: Math.abs(remaining),
      unit: t("common.kcal"),
      label: over ? t("today.overBy") : t("today.remaining"),
      color: over ? OVER : GREEN,
    },
  ]

  return (
    <div className="flex flex-col items-center gap-8 py-2">
      {/* Rings + centered headline numbers */}
      <div className="relative grid place-items-center">
        <svg viewBox="0 0 240 240" className="size-60 sm:size-64">
          <Ring radius={104} stroke={15} color={GREEN} pct={calPct} delay={0.15} />
          <Ring radius={78} stroke={15} color={BLUE} pct={proPct} delay={0.32} />
        </svg>
        <div className="absolute flex flex-col items-center">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.5, duration: 0.4 }}
            className="font-heading text-[2.75rem] font-semibold leading-none tabular-nums tracking-tight sm:text-5xl"
            style={{ color: GREEN }}
          >
            {formatNumber(calories)}
          </motion.div>
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.6, duration: 0.4 }}
            className="mt-1 font-heading text-xl font-semibold leading-none tabular-nums tracking-tight sm:text-2xl"
            style={{ color: BLUE }}
          >
            {formatNumber(protein)}
          </motion.div>
        </div>
      </div>

      {/* Ring legend — names the two headline numbers */}
      <div className="flex items-center justify-center gap-8">
        <Legend
          color={GREEN}
          icon={Flame}
          label={t("macro.calories")}
          value={`${formatNumber(calories)} / ${formatNumber(goals.calories)} ${t("common.kcal")}`}
        />
        <Legend
          color={BLUE}
          icon={Beef}
          label={t("macro.protein")}
          value={`${formatNumber(protein)} / ${formatNumber(goals.protein)} ${t("common.g")}`}
        />
      </div>

      {/* Three-up stat strip */}
      <div className="grid w-full max-w-md grid-cols-3 gap-2">
        {stats.map((s) => (
          <div key={s.label} className="flex flex-col items-center gap-1.5 text-center">
            <s.icon className="size-4" style={{ color: s.color }} />
            <div
              className="font-heading text-xl font-semibold leading-none tabular-nums sm:text-2xl"
              style={{ color: s.color }}
            >
              {formatNumber(s.value)}
              <span className="ms-0.5 text-[0.7rem] font-normal text-white/45">{s.unit}</span>
            </div>
            <div className="text-[0.7rem] uppercase tracking-[0.14em] text-white/45">{s.label}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
