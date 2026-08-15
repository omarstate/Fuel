// Direct-from-browser Open Food Facts lookup — the FALLBACK path used when the
// backend proxy fails, most often because OFF rate-limits the backend's shared
// Render egress IP while the user's own IP is fine. OFF's API sends
// `Access-Control-Allow-Origin: *`, so this works cross-origin.
//
// The normalization mirrors backend/src/services/barcode.service.js (and the
// iOS port in ios/Fuel/Core/Networking/OpenFoodFacts.swift) — if the shape or
// the rules change in one place, change all three.

import type { BarcodeProduct } from "@/lib/api"

const OFF_ENDPOINT = (code: string) =>
  `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json`

const TIMEOUT_MS = 8_000

// Only the fields we need — keeps the response small and fast.
const FIELDS = [
  "product_name",
  "brands",
  "serving_size",
  "serving_quantity",
  "nutriments",
].join(",")

const KJ_PER_KCAL = 4.184

const clampInt = (value: unknown): number => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n >= 0 ? n : 0
}

type Nutriments = Record<string, unknown>

// A nutriment that is present but empty ("" or null) must NOT read as 0 —
// JS Number("") is 0, which would mask a valid kilojoule fallback.
const numberOrNull = (value: unknown): number | null => {
  if (value == null) return null
  if (typeof value === "string" && value.trim() === "") return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

// Energy per 100g, always as kcal. OFF usually has energy-kcal_100g; if a
// product only carries kilojoules, convert.
const kcalPer100 = (n: Nutriments): number => {
  const kcal = numberOrNull(n["energy-kcal_100g"])
  if (kcal !== null) return kcal
  const kj = numberOrNull(n["energy-kj_100g"]) ?? numberOrNull(n["energy_100g"])
  return kj !== null ? kj / KJ_PER_KCAL : 0
}

// First non-empty comma segment of OFF's `brands` — entries like ",Nestlé"
// exist in the crowdsourced data.
const firstBrand = (value: unknown): string | null => {
  if (typeof value !== "string") return null
  return toNullableString(value.split(",").find((part) => part.trim()) ?? null)
}

const toNullableString = (value: unknown): string | null => {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  return trimmed || null
}

const toPositiveNumber = (value: unknown): number | null => {
  const n = Number(value)
  return Number.isFinite(n) && n > 0 ? n : null
}

const incomplete = (barcode: string, name: string | null, brand: string | null): BarcodeProduct => ({
  found: true,
  ok: false,
  barcode,
  name,
  brand,
  basis: "per_100g",
  servingSize: "",
  servingGrams: null,
  calories: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
  confidence: null,
  note: "Found in the database, but it has no nutrition facts. Snap the label or enter the values.",
})

const notFound = (barcode: string): BarcodeProduct => ({
  found: false,
  ok: false,
  barcode,
  name: null,
  brand: null,
  basis: "per_100g",
  servingSize: "",
  servingGrams: null,
  calories: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
  confidence: null,
  note: "Not in the barcode database. Snap the nutrition label instead.",
})

export async function lookupBarcodeDirect(code: string): Promise<BarcodeProduct> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  let res: Response
  try {
    res = await fetch(`${OFF_ENDPOINT(code)}?fields=${FIELDS}`, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    })
  } catch {
    throw new Error("Couldn't reach the barcode database. Check your connection and try again.")
  } finally {
    clearTimeout(timer)
  }

  // v2 returns 404 for an unknown barcode (older paths use 200 + status:0,
  // handled below). Both mean "not in the database", not an outage.
  if (res.status === 404) return notFound(code)

  if (!res.ok) {
    throw new Error(`The barcode database returned an error (status ${res.status}). Try again shortly.`)
  }

  let payload: { status?: number; product?: Record<string, unknown> } | null
  try {
    payload = await res.json()
  } catch {
    throw new Error("The barcode database sent an unreadable response.")
  }

  if (!payload || payload.status !== 1 || !payload.product) return notFound(code)

  const product = payload.product
  const nutriments = (product.nutriments ?? {}) as Nutriments
  const name = toNullableString(product.product_name)
  const brand = firstBrand(product.brands)

  const calories = kcalPer100(nutriments)

  // "Usable" means at least one whole calorie AFTER rounding — the same gate
  // the backend applies, so ok:true always means representable macros. A
  // product with only a name is incomplete and the UI routes the user to the
  // label-photo fallback.
  if (clampInt(calories) <= 0) return incomplete(code, name, brand)

  return {
    found: true,
    ok: true,
    barcode: code,
    name,
    brand,
    basis: "per_100g",
    servingSize: toNullableString(product.serving_size) ?? "",
    servingGrams: toPositiveNumber(product.serving_quantity),
    calories: clampInt(calories),
    protein: clampInt(nutriments.proteins_100g),
    carbs: clampInt(nutriments.carbohydrates_100g),
    fat: clampInt(nutriments.fat_100g),
    confidence: null,
    note: brand ? `${brand} · via Open Food Facts` : "via Open Food Facts",
  }
}
