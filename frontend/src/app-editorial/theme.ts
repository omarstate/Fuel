import type { Mode } from "@/components/site/mode-context"

/**
 * Light-editorial accents, keyed by mode. Each mode has:
 *  - accent:    the fill color (rings, bars, pills, primary marks)
 *  - ink:       a darker, text-safe shade for labels/icons on the bone canvas
 *  - spark:     a contrasting dot on the logo badge
 *
 * Nutrition = green, Workouts = orange. The shared `modeColors` (neon volt)
 * still drives the dark `/app`; this map only themes the editorial app.
 */
export const editorialAccent: Record<Mode, string> = {
  nutrition: "#8a9b3b",
  workouts: "#ff6b35",
}

export const editorialAccentInk: Record<Mode, string> = {
  nutrition: "#627218",
  workouts: "#b5431c",
}

export const editorialSpark: Record<Mode, string> = {
  nutrition: "#ff6b35",
  workouts: "#d7fa34",
}
