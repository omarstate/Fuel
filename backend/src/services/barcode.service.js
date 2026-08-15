// Barcode → nutrition lookup via Open Food Facts (OFF), a free, open, crowd-
// sourced product database (ODbL — we credit it in the UI). No API key; OFF
// asks only for a descriptive User-Agent and reasonable request rates.
//
// The result is normalized into the SAME shape the photo label-extraction
// returns (per-100g basis + macros + optional serving grams), so the frontend
// review/scale/log step is shared between the two features. A barcode that
// isn't in OFF comes back as { found: false } so the client can fall back to
// "snap the label instead".
//
// OFF rate-limits per IP and the Render deployment shares its egress IP with
// other tenants, so server-side OFF calls often 429. Two defenses layered here:
// 1. A Supabase read-through cache (barcode_products, migration 0012) serves
//    repeat scans without touching OFF; a stale row still beats an OFF error.
//    Everything cache fails soft, so the code works before the migration runs.
// 2. Clients treat a 5xx from this route as "try OFF directly from the device"
//    (frontend/src/lib/openfoodfacts.ts and
//    ios/Fuel/Core/Networking/OpenFoodFacts.swift — the normalization below is
//    mirrored there; change all three together) and report successes back via
//    reportBarcode so the shared cache still fills.

import { supabase } from "../config/supabase.js"
import { env } from "../config/env.js"
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

// A nutriment that is present but empty ("" or null) must NOT read as 0 —
// JS Number("") is 0, which would mask a valid kilojoule fallback.
const numberOrNull = (value) => {
  if (value == null) return null
  if (typeof value === "string" && value.trim() === "") return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

// Energy per 100g, always as kcal. OFF usually has energy-kcal_100g; if a
// product only carries kilojoules, convert.
const kcalPer100 = (n) => {
  const kcal = numberOrNull(n["energy-kcal_100g"])
  if (kcal !== null) return kcal
  const kj = numberOrNull(n["energy-kj_100g"]) ?? numberOrNull(n["energy_100g"])
  return kj !== null ? kj / KJ_PER_KCAL : 0
}

// First non-empty comma segment of OFF's `brands` — entries like ",Nestlé"
// exist in the crowdsourced data.
const firstBrand = (value) => {
  if (typeof value !== "string") return null
  return toNullableString(value.split(",").find((part) => part.trim()) ?? null)
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

const fetchFromOpenFoodFacts = async (barcode) => {
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

  // OFF throttles per IP; on shared hosting this can be chronic, which is why
  // clients fall back to calling OFF directly when they see this 503.
  if (res.status === 429) {
    throw ApiError.serviceUnavailable(
      "The barcode database is rate-limiting the server right now. Try again shortly."
    )
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
  const brand = firstBrand(product.brands)

  const calories = kcalPer100(nutriments)
  const protein = Number(nutriments.proteins_100g)
  const carbs = Number(nutriments.carbohydrates_100g)
  const fat = Number(nutriments.fat_100g)

  // "Usable" means at least one whole calorie AFTER rounding — the same gate
  // the report endpoint's validation applies, so every ok:true product is
  // representable in the cache. Products with only a name are incomplete and
  // the UI routes the user to the label-photo fallback.
  if (clampInt(calories) <= 0) {
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

// ---------------------------------------------------------------------------
// Supabase read-through cache (barcode_products, migration 0012). Every call
// fails soft — before the migration runs, reads return null and writes no-op,
// so lookups behave exactly as they did without the cache.
// ---------------------------------------------------------------------------

const CACHE_TABLE = "barcode_products"

// Cached products are refreshed from OFF monthly (reformulations happen), but
// a stale row is still served when OFF itself is down or rate-limiting.
const STALE_AFTER_MS = 30 * 24 * 60 * 60 * 1000

const readCache = async (barcode) => {
  if (!env.isSupabaseConfigured) return null
  const { data, error } = await supabase
    .from(CACHE_TABLE)
    .select("*")
    .eq("barcode", barcode)
    .maybeSingle()
  if (error) return null // table missing (migration not run) or transient — miss
  return data
}

const writeCache = async (barcode, product, source) => {
  if (!env.isSupabaseConfigured) return
  const row = {
    barcode,
    name: product.name,
    brand: product.brand,
    serving_size: product.servingSize ?? "",
    serving_grams: product.servingGrams,
    calories: clampInt(product.calories),
    protein: clampInt(product.protein),
    carbs: clampInt(product.carbs),
    fat: clampInt(product.fat),
    source,
    updated_at: new Date().toISOString(),
  }
  // All errors below are ignored: the cache is best-effort until the migration
  // runs (and 'client' inserts routinely fail on duplicate keys by design).
  if (source === "off") {
    // Authoritative — always wins, including over existing 'client' rows.
    await supabase.from(CACHE_TABLE).upsert(row, { onConflict: "barcode" })
    return
  }
  // Client reports must never replace an authoritative row. Insert-if-absent,
  // then update restricted to rows that are still client-sourced — each
  // statement is atomic, so no check-then-write race can demote an 'off' row.
  const { error } = await supabase.from(CACHE_TABLE).insert(row)
  if (!error) return
  await supabase.from(CACHE_TABLE).update(row).eq("barcode", barcode).eq("source", "client")
}

const deleteClientRow = async (barcode) => {
  if (!env.isSupabaseConfigured) return
  // Only ever removes 'client' rows — see lookupBarcode. Errors ignored.
  await supabase.from(CACHE_TABLE).delete().eq("barcode", barcode).eq("source", "client")
}

const isFresh = (row) => Date.now() - new Date(row.updated_at).getTime() < STALE_AFTER_MS

const rowToProduct = (row) => {
  const brand = toNullableString(row.brand)
  return {
    found: true,
    ok: true,
    barcode: row.barcode,
    name: toNullableString(row.name),
    brand,
    basis: "per_100g",
    servingSize: toNullableString(row.serving_size) ?? "",
    servingGrams: toPositiveNumber(row.serving_grams),
    calories: clampInt(row.calories),
    protein: clampInt(row.protein),
    carbs: clampInt(row.carbs),
    fat: clampInt(row.fat),
    confidence: null,
    note: brand ? `${brand} · via Open Food Facts` : "via Open Food Facts",
  }
}

// Cache-first lookup: a fresh AUTHORITATIVE ('off') row skips OFF entirely; a
// stale one is refreshed but still served if OFF errors. 'client'-sourced rows
// are unverified hints: they never short-circuit a live OFF fetch (a fabricated
// report must not shadow the real data), serve only as a fallback when OFF
// errors, and are deleted the moment OFF authoritatively denies the barcode.
// Only usable products (ok:true) are ever cached, so "not found" is re-checked
// on every scan.
export const lookupBarcode = async (barcode) => {
  const cached = await readCache(barcode)
  if (cached && cached.source === "off" && isFresh(cached)) return rowToProduct(cached)

  let result
  try {
    result = await fetchFromOpenFoodFacts(barcode)
  } catch (err) {
    if (cached) return rowToProduct(cached) // stale/unverified beats an error
    throw err
  }

  if (result.ok) {
    await writeCache(barcode, result, "off")
    return result
  }
  // OFF answered but says unknown/incomplete.
  if (cached) {
    // A delisted product we once fetched ourselves: keep the last good data.
    if (cached.source === "off") return rowToProduct(cached)
    // A client row OFF has never confirmed is unverifiable — drop it.
    await deleteClientRow(barcode)
  }
  return result
}

// A client that fell back to calling OFF directly (because this server's IP
// was rate-limited) contributes its result so the next scan — by anyone —
// hits the cache. Values are zod-bounded upstream; still best-effort only.
export const reportBarcode = async (barcode, product) => {
  await writeCache(barcode, product, "client")
}
