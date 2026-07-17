// Barcode → nutrition lookup via Open Food Facts (OFF), a free, open, crowd-
// sourced product database (ODbL — we credit it in the UI). No API key; OFF
// asks only for a descriptive User-Agent and reasonable request rates.
//
// The result is normalized into the SAME shape the photo label-extraction
// returns (per-100g basis + macros + optional serving grams), so the frontend
// review/scale/log step is shared between the two features. A barcode that
// isn't in OFF comes back as { found: false } so the client can fall back to
// "snap the label instead".

import { ApiError } from "../utils/api-error.js"

const OFF_ENDPOINT = (code) =>
  `https://world.openfoodfacts.org/api/v2/product/${code}.json`

// OFF etiquette: identify the app in the User-Agent. No public URL yet, so this
// is descriptive rather than a live link.
const USER_AGENT = "Fuel/1.0 (Egypt nutrition tracker)"
const TIMEOUT_MS = 8_000

// Only the fields we need — keeps the response small and fast.
const FIELDS = [
  "product_name",
  "brands",
  "serving_size",
  "serving_quantity",
  "nutriments",
].join(",")

const clampInt = (value) => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n >= 0 ? n : 0
}

const KJ_PER_KCAL = 4.184

// Energy per 100g, always as kcal. OFF usually has energy-kcal_100g; if a
// product only carries kilojoules, convert.
const kcalPer100 = (n) => {
  if (Number.isFinite(Number(n["energy-kcal_100g"]))) return Number(n["energy-kcal_100g"])
  const kj = Number(n["energy-kj_100g"] ?? n["energy_100g"])
  if (Number.isFinite(kj)) return kj / KJ_PER_KCAL
  return 0
}

const toNullableString = (value) => {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  return trimmed || null
}

const toPositiveNumber = (value) => {
  const n = Number(value)
  return Number.isFinite(n) && n > 0 ? n : null
}

// A found product with no usable macros (crowdsourced entries are often just a
// name + photo). Surface the name so the user can start, but flag it so the
// client nudges them to snap the label or fill values in.
const incomplete = (barcode, name, brand) => ({
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

const notFound = (barcode) => ({
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

export const lookupBarcode = async (barcode) => {
  const url = `${OFF_ENDPOINT(barcode)}?fields=${FIELDS}`

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  let res
  try {
    res = await fetch(url, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
      signal: controller.signal,
    })
  } catch {
    throw ApiError.serviceUnavailable(
      "Couldn't reach the barcode database. Check your connection and try again."
    )
  } finally {
    clearTimeout(timer)
  }

  // OFF's v2 API returns 404 for an unknown barcode (older paths used 200 with
  // status:0 — handled below). Both mean "not in the database", not an outage.
  if (res.status === 404) {
    return notFound(barcode)
  }

  if (!res.ok) {
    throw ApiError.serviceUnavailable(
      `The barcode database returned an error (status ${res.status}). Try again shortly.`
    )
  }

  let payload
  try {
    payload = await res.json()
  } catch {
    throw ApiError.serviceUnavailable("The barcode database sent an unreadable response.")
  }

  // OFF returns HTTP 200 with status:0 for an unknown barcode.
  if (!payload || payload.status !== 1 || !payload.product) {
    return notFound(barcode)
  }

  const product = payload.product
  const nutriments = product.nutriments ?? {}
  const name = toNullableString(product.product_name)
  const brand = toNullableString((product.brands ?? "").split(",")[0])

  const calories = kcalPer100(nutriments)
  const protein = Number(nutriments.proteins_100g)
  const carbs = Number(nutriments.carbohydrates_100g)
  const fat = Number(nutriments.fat_100g)

  // "Usable" means at least calories — a product with only a name is treated as
  // incomplete so the UI routes the user to the label-photo fallback.
  if (!Number.isFinite(calories) || calories <= 0) {
    return incomplete(barcode, name, brand)
  }

  return {
    found: true,
    ok: true,
    barcode,
    name,
    brand,
    basis: "per_100g",
    servingSize: toNullableString(product.serving_size) ?? "",
    servingGrams: toPositiveNumber(product.serving_quantity),
    calories: clampInt(calories),
    protein: clampInt(protein),
    carbs: clampInt(carbs),
    fat: clampInt(fat),
    confidence: null,
    note: brand ? `${brand} · via Open Food Facts` : "via Open Food Facts",
  }
}
