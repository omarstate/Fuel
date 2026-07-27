// Voice meal logging — parse a spoken transcript into loggable items.
//
// The app transcribes speech on-device (Egyptian Arabic or English) and posts
// the text here. ONE Gemini call does parsing AND catalog matching together:
// it extracts each food + quantity + the target meal section, and matches each
// item against the catalog (names + the `aliases` column that bridges Arabic
// speech to English catalog names). Whatever it can't match gets a grounded,
// Egypt-first estimate — one search-grounded call per item, in parallel, each
// soft-failing on its own so one bad item never kills the batch.
//
// This service NEVER writes log rows: the app inserts those straight into
// Supabase under RLS. `commitVoiceLog` persists catalog changes only.

import { supabase } from "../config/supabase.js"
import { rowToCatalogMeal } from "../models/catalog-meal.model.js"
import { generateJson } from "./gemini.client.js"
import { ApiError } from "../utils/api-error.js"
import {
  voiceParseSchema,
  voiceParsedItemSchema,
  voiceEstimateSchema,
  clampFactor,
  normalizeRanges,
  roundInt,
  MAX_VOICE_ITEMS,
} from "../validators/ai-voice.validator.js"

const SELECT_WITH_CATEGORY = "*, meal_categories(id, name, slug)"

// How much of the catalog we show the model. Names + aliases + serving size
// only, so 500 rows stay well inside a sane prompt budget.
const CANDIDATE_LIMIT = 500
const CANDIDATE_COLUMNS_WITH_ALIASES = "id, name, aliases, serving_size"
const CANDIDATE_COLUMNS = "id, name, serving_size"

// Aliases kept per catalog meal (oldest first, newest dropped past the cap).
const MAX_ALIASES_PER_MEAL = 12
// Aliases per row we bother showing the model.
const ALIASES_IN_PROMPT = 6

const MANUAL_ENTRY_NOTE = {
  en: "Couldn't estimate this one automatically — enter its macros by hand.",
  ar: "مقدرناش نحسب العنصر ده لوحدنا — دخّل السعرات والماكروز بنفسك.",
}

// -------------------------------------------------------------------------
// `aliases` column tolerance
// -------------------------------------------------------------------------

// 0010_meal_aliases.sql is applied by hand, so every read/write that mentions
// `aliases` must survive the column not existing yet. Postgres reports an
// unknown column as 42703 ("undefined_column"); PostgREST sometimes only says so
// in the message, hence the text check as well.
const isMissingAliasesColumn = (error) => {
  if (!error) return false
  if (error.code === "42703") return true
  const text = `${error.message ?? ""} ${error.details ?? ""} ${error.hint ?? ""}`.toLowerCase()
  return text.includes("aliases") && (text.includes("column") || text.includes("schema"))
}

const asAliasArray = (value) => (Array.isArray(value) ? value.filter((v) => typeof v === "string") : [])

// -------------------------------------------------------------------------
// Step 1 — compact catalog for the matcher
// -------------------------------------------------------------------------

const fetchCandidates = async () => {
  const withAliases = await supabase
    .from("catalog_meals")
    .select(CANDIDATE_COLUMNS_WITH_ALIASES)
    .limit(CANDIDATE_LIMIT)

  if (!withAliases.error) {
    return (withAliases.data ?? []).map((row) => ({ ...row, aliases: asAliasArray(row.aliases) }))
  }

  if (!isMissingAliasesColumn(withAliases.error)) {
    throw ApiError.badRequest("Failed to load meals", withAliases.error.message)
  }

  // Migration hasn't run — match on names alone.
  const plain = await supabase.from("catalog_meals").select(CANDIDATE_COLUMNS).limit(CANDIDATE_LIMIT)
  if (plain.error) throw ApiError.badRequest("Failed to load meals", plain.error.message)
  return (plain.data ?? []).map((row) => ({ ...row, aliases: [] }))
}

// One JSON object per line, and only the fields the matcher needs — empty
// aliases and null serving sizes are omitted to keep the prompt small.
const catalogLine = (row) => {
  const entry = { id: row.id, name: row.name }
  const aliases = row.aliases.slice(0, ALIASES_IN_PROMPT)
  if (aliases.length > 0) entry.aliases = aliases
  if (row.serving_size) entry.servingSize = row.serving_size
  return JSON.stringify(entry)
}

// -------------------------------------------------------------------------
// Step 2 — the parse + match prompt
// -------------------------------------------------------------------------

const PARSE_PROMPT = ({ transcript, catalogLines, catalogCount }) =>
  `You are the parser behind VOICE meal logging in a nutrition app. The user spoke out loud and this is the on-device transcription:
"""
${transcript}
"""

The users are primarily in EGYPT. They speak colloquial EGYPTIAN ARABIC, English, or both mixed inside one sentence. Transcription is imperfect — read through small mis-hearings instead of taking them literally.

Egyptian colloquial you are expected to understand (not exhaustive):
- Numbers as words: واحد/واحدة = 1, اتنين = 2, تلاتة/تلات = 3, اربعة/اربع = 4, خمسة/خمس = 5, ستة = 6, سبعة = 7, تمانية = 8, تسعة = 9, عشرة = 10; نص = a half (0.5), ربع = a quarter (0.25), تلت = a third. Arabic-Indic digits (٣) mean the same as Western ones (3).
- Portions and containers: كوباية/كوب = a cup or glass, معلقة = a spoon, معلقة كبيرة = tablespoon, معلقة صغيرة = teaspoon, رغيف = one loaf of baladi bread, شريحة = a slice, حبة = one piece, حبتين = two pieces, طبق = a plate, علبة = a can/tub, كيس = a bag/packet, نص كيلو = half a kilo.
- Foods: فول = fava beans (foul), طعمية/فلافل = falafel, عيش بلدي = baladi bread, عيش فينو = fino bread, عيش توست/توست = toast, بيض مسلوق = boiled eggs, بيض مقلي = fried eggs, جبنة قريش = karish cheese, جبنة بيضاء = white cheese, لبن = milk, زبادي = yoghurt, فراخ = chicken, لحمة = beef, أرز = rice, مكرونة = pasta, بطاطس = potatoes, كشري = koshari, ملوخية = molokhia, محشي = stuffed vegetables, شاورما, فتة, بسبوسة, مانجو = mango, تمر = dates.

TASK 1 — ITEMS. Extract every DISTINCT food or drink the user says they ate or drank, in the order spoken, keeping the quantity and unit AS SPOKEN. Never merge two different foods into one item. Never break one dish down into its ingredients. Never invent an item that was not said. Ignore filler and non-food words ("ضيفهم على", "سجّل", "log this", "add", "please").

TASK 2 — MEAL SECTION. Only if the user actually says which meal it belongs to, map it: فطار/الفطار/فطور/breakfast → "breakfast"; غدا/الغدا/غداء/lunch → "lunch"; عشا/العشا/عشاء/dinner → "dinner"; سناك/تصبيرة/وجبة خفيفة/snack → "snack". If they do not say, return null — never guess from the food itself.

TASK 3 — CATALOG MATCH. The app's meal catalog is below, one compact JSON object per line: {"id","name","aliases","servingSize"}. Set "catalogId" to an entry's id ONLY when the item is genuinely the SAME food. Colloquial Egyptian names DO count as a match (بيض مسلوق = "Boiled Eggs", عيش توست = "Toast", فول = "Foul Medames"), and so does anything listed in that entry's "aliases". A different preparation, a different brand, or a mere category cousin is NOT a match (فراخ مشوية is not "Fried Chicken"). When you are not sure, return null instead of a wrong match — a wrong match logs the wrong food and the wrong macros. Only ever use an id that appears in the list below.

TASK 4 — FACTOR. When you matched an entry, set "factor" to (the amount the user spoke) ÷ (that entry's "servingSize"). Examples: spoken "3 eggs" against servingSize "1 egg (50g)" → 3; spoken "200ml" against "1 cup (240ml)" → 0.83; spoken "نص رغيف" against "1 loaf" → 0.5; spoken with no amount → 1. If the entry has no servingSize or the ratio is not workable, return null.

CATALOG (${catalogCount} entries):
${catalogLines}

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "mealType": "breakfast" | "lunch" | "dinner" | "snack" | null,
  "items": [
    {
      "spoken": "the words the user used for this item, in the original language",
      "name": "concise canonical ENGLISH name, e.g. Boiled Eggs",
      "nameAr": "concise Arabic name, e.g. بيض مسلوق",
      "quantity": number | null,
      "unit": "unit as spoken, e.g. egg, slice, ml, رغيف" | null,
      "catalogId": "an id from the catalog above" | null,
      "factor": number | null,
      "confidence": "high" | "medium" | "low"
    }
  ]
}

Return at most ${MAX_VOICE_ITEMS} items. If the transcript mentions no food or drink at all, return {"mealType": null, "items": []}.`

// -------------------------------------------------------------------------
// Step 4 — the Egypt-first grounded estimate prompt (per unmatched item)
// -------------------------------------------------------------------------

const ESTIMATE_PROMPT = ({ spoken, name, quantity, unit, lang = "en" }) => {
  const amount = [
    quantity == null ? null : `quantity ${quantity}`,
    unit ? `unit "${unit}"` : null,
  ]
    .filter(Boolean)
    .join(", ")

  const arabicInstruction =
    lang === "ar"
      ? `

Write "name", "servingSize" and "note" in Arabic, in wording an Egyptian would use. Keep brand names in their original Latin script. The JSON keys stay in English, and every number stays as Western digits.`
      : ""

  return `You are a nutrition estimator for a fitness app whose users are primarily in Egypt.

The user said out loud that they had: "${spoken}".
Canonical name for it: "${name}".${amount ? `\nParsed amount — ${amount}.` : ""}

Use Google Search to find accurate nutrition facts, and PRIORITIZE the Egyptian market:
1. First, look for the item exactly as sold or cooked in Egypt — Egyptian branch menus, Egyptian fast-food portions, local Egyptian brands, Egyptian home-cooking portions, and Arabic-language sources. Egyptian portion sizes and recipes differ from other countries, so prefer local data.
2. Only if no Egyptian data exists, use the closest Middle-East / regional equivalent.
3. Only if that is also unavailable, fall back to global data.

CRITICAL — estimate the macros for THE WHOLE AMOUNT THE USER SPOKE, not for one generic serving. "3 boiled eggs" means the totals for 3 eggs, with "servingSize" reading "3 eggs (~150g)". "200ml skimmed milk" means the totals for 200ml. If no amount was spoken, assume one typical Egyptian serving and say which one in "servingSize".

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "name": "concise name for what was eaten, e.g. Boiled Eggs",
  "servingSize": "the amount these macros cover, e.g. 3 eggs (~150g)",
  "calories": integer kcal for that amount,
  "protein": integer grams,
  "carbs": integer grams,
  "fat": integer grams,
  "ranges": {"calories":[min,max],"protein":[min,max],"carbs":[min,max],"fat":[min,max]} | null,
  "sourceUrl": "the URL the numbers came from" | null,
  "confidence": "high" | "medium" | "low",
  "note": "one short sentence on the source or any assumption you made"
}

All macros must be non-negative integers covering the spoken amount. "ranges" is a plausible min-max band around each point estimate, with min <= point <= max; return null only when the numbers are solid enough that a band adds nothing. If a value is genuinely unknown, give your best reasonable estimate rather than 0.${arabicInstruction}`
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

const httpUrlOrNull = (value) => {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  if (!trimmed) return null
  try {
    const url = new URL(trimmed)
    return url.protocol === "http:" || url.protocol === "https:" ? trimmed : null
  } catch {
    return null
  }
}

const softFailEstimate = (item, lang) => ({
  kind: "estimate",
  ok: false,
  spoken: item.spoken,
  quantity: item.quantity,
  unit: item.unit,
  name: item.spoken,
  servingSize: "",
  calories: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
  ranges: null,
  sourceUrl: null,
  confidence: null,
  note: MANUAL_ENTRY_NOTE[lang] ?? MANUAL_ENTRY_NOTE.en,
})

const estimateOne = async (item, lang) => {
  try {
    const { data, sources } = await generateJson({
      useSearch: true,
      temperature: 0.2,
      prompt: ESTIMATE_PROMPT({ ...item, lang }),
    })

    const parsed = voiceEstimateSchema.parse(data)
    const name = parsed.name?.trim() || item.name || item.spoken

    return {
      kind: "estimate",
      ok: true,
      spoken: item.spoken,
      quantity: item.quantity,
      unit: item.unit,
      name,
      servingSize: parsed.servingSize?.trim() ?? "",
      calories: roundInt(parsed.calories),
      protein: roundInt(parsed.protein),
      carbs: roundInt(parsed.carbs),
      fat: roundInt(parsed.fat),
      ranges: normalizeRanges(parsed.ranges),
      sourceUrl: httpUrlOrNull(parsed.sourceUrl) ?? httpUrlOrNull(sources[0]?.uri),
      confidence: parsed.confidence ?? null,
      note: parsed.note?.trim() ?? "",
    }
  } catch {
    // Soft-fail this one item only — the review sheet offers manual entry.
    return softFailEstimate(item, lang)
  }
}

// -------------------------------------------------------------------------
// Endpoint A — parse a transcript (writes nothing)
// -------------------------------------------------------------------------

/**
 * @param {{ transcript: string, lang?: "en" | "ar" }} input
 * @returns {Promise<{ mealType: string|null, items: object[] }>} items in spoken order
 */
export const parseVoiceLog = async ({ transcript, lang = "en" }) => {
  const candidates = await fetchCandidates()
  const candidateIds = new Set(candidates.map((row) => row.id))

  const { data } = await generateJson({
    useSearch: false,
    temperature: 0,
    prompt: PARSE_PROMPT({
      transcript,
      catalogLines: candidates.map(catalogLine).join("\n"),
      catalogCount: candidates.length,
    }),
  })

  const parsed = voiceParseSchema.parse(data)

  // Drop entries the model malformed rather than failing the whole utterance.
  const items = []
  for (const raw of parsed.items) {
    const result = voiceParsedItemSchema.safeParse(raw)
    if (!result.success) continue

    const item = result.data
    const spoken = item.spoken?.trim() || item.name
    // Never trust a model-supplied id: it must be one we actually sent.
    const catalogId = item.catalogId && candidateIds.has(item.catalogId) ? item.catalogId : null

    items.push({
      spoken,
      name: item.name,
      nameAr: item.nameAr ?? null,
      quantity: item.quantity ?? null,
      unit: item.unit ?? null,
      catalogId,
      factor: clampFactor(item.factor),
      confidence: item.confidence ?? null,
    })

    if (items.length >= MAX_VOICE_ITEMS) break
  }

  if (items.length === 0) {
    throw ApiError.badRequest("Couldn't find any food items in that")
  }

  // Full rows for the matched meals, so the app gets real CatalogMeal DTOs.
  // `select("*")` is column-agnostic, so no aliases fallback is needed here.
  const matchedIds = [...new Set(items.map((item) => item.catalogId).filter(Boolean))]
  const mealsById = new Map()
  if (matchedIds.length > 0) {
    const { data: rows, error } = await supabase
      .from("catalog_meals")
      .select(SELECT_WITH_CATEGORY)
      .in("id", matchedIds)

    if (error) throw ApiError.badRequest("Failed to load matched meals", error.message)
    for (const row of rows ?? []) mealsById.set(row.id, rowToCatalogMeal(row))
  }

  // Catalog matches resolve locally; everything else gets its own grounded
  // estimate. Order is preserved by writing into a pre-sized array.
  const results = new Array(items.length)
  const pending = []

  items.forEach((item, index) => {
    const meal = item.catalogId ? mealsById.get(item.catalogId) : null
    if (meal) {
      results[index] = {
        kind: "catalog",
        spoken: item.spoken,
        quantity: item.quantity,
        unit: item.unit,
        factor: item.factor,
        meal,
      }
    } else {
      pending.push({ index, item })
    }
  })

  await Promise.all(
    pending.map(async ({ index, item }) => {
      results[index] = await estimateOne(item, lang)
    })
  )

  return { mealType: parsed.mealType ?? null, items: results }
}

// -------------------------------------------------------------------------
// Endpoint B — commit catalog changes after the user confirms
// -------------------------------------------------------------------------

// Look up the ai-discovered category once. Falls back to the first category if
// the 0008 seed hasn't run yet; returns null only if there are no categories.
// (Same pattern as ai.service.js — deliberately duplicated, not imported.)
const getAiCategoryId = async () => {
  const { data: aiCat } = await supabase
    .from("meal_categories")
    .select("id")
    .eq("slug", "ai-discovered")
    .maybeSingle()

  if (aiCat?.id) return aiCat.id

  const { data: firstCat } = await supabase
    .from("meal_categories")
    .select("id")
    .order("sort_order", { ascending: true })
    .limit(1)
    .maybeSingle()

  return firstCat?.id ?? null
}

// `%` and `_` are ILIKE wildcards — a meal named "100% Whey" must not match
// everything. Escaped with a backslash, ILIKE's default escape character.
const escapeLikePattern = (value) => value.replace(/[\\%_]/g, (char) => `\\${char}`)

/**
 * Merge spoken aliases into a meal's existing list: trimmed, case-insensitively
 * unique, never equal to the meal's own name, capped. Pure — no DB access.
 */
export const mergeAliases = (existing, incoming, mealName) => {
  const nameKey = (mealName ?? "").trim().toLowerCase()
  const seen = new Set()
  const merged = []

  for (const value of [...asAliasArray(existing), ...asAliasArray(incoming)]) {
    const trimmed = value.trim()
    if (!trimmed) continue
    const key = trimmed.toLowerCase()
    if (key === nameKey || seen.has(key)) continue
    seen.add(key)
    merged.push(trimmed)
    if (merged.length >= MAX_ALIASES_PER_MEAL) break
  }

  return merged
}

const insertNewMeal = async (userId, input, categoryId) => {
  const row = {
    name: input.name,
    description: null,
    category_id: categoryId,
    serving_size: input.servingSize,
    calories: input.calories,
    protein: input.protein,
    carbs: input.carbs,
    fat: input.fat,
    created_by: userId,
    ai_source: "estimate",
    source_url: input.sourceUrl ?? null,
    macro_ranges: normalizeRanges(input.ranges),
    aliases: mergeAliases([], input.aliases, input.name),
  }

  const first = await supabase.from("catalog_meals").insert(row).select(SELECT_WITH_CATEGORY).single()
  if (!first.error) return rowToCatalogMeal(first.data)

  if (!isMissingAliasesColumn(first.error)) {
    throw ApiError.badRequest("Failed to save meal", first.error.message)
  }

  // Migration hasn't run — save the meal without its aliases rather than fail.
  const { aliases, ...withoutAliases } = row
  const retry = await supabase
    .from("catalog_meals")
    .insert(withoutAliases)
    .select(SELECT_WITH_CATEGORY)
    .single()

  if (retry.error) throw ApiError.badRequest("Failed to save meal", retry.error.message)
  return rowToCatalogMeal(retry.data)
}

// Best-effort alias learning for a meal that already exists. Any failure —
// including the column not existing yet — is swallowed: teaching the catalog a
// new phrase must never break logging.
const applyAliasUpdate = async (update) => {
  try {
    const current = await supabase
      .from("catalog_meals")
      .select("id, name, aliases")
      .eq("id", update.catalogMealId)
      .maybeSingle()

    if (current.error || !current.data) return false

    const merged = mergeAliases(current.data.aliases, update.aliases, current.data.name)
    if (merged.length === 0) return false

    const { error } = await supabase
      .from("catalog_meals")
      .update({ aliases: merged })
      .eq("id", update.catalogMealId)

    return !error
  } catch {
    return false
  }
}

/**
 * @param {string} userId
 * @param {{ newMeals: object[], aliasUpdates: object[] }} input
 * @returns {Promise<{ meals: {name: string, meal: object}[], aliasesUpdated: number }>}
 *   `name` echoes the request so the app can map created meals back to the
 *   review rows it sent, and link its log rows to the new catalog ids.
 */
export const commitVoiceLog = async (userId, { newMeals = [], aliasUpdates = [] }) => {
  const meals = []
  const categoryId = newMeals.length > 0 ? await getAiCategoryId() : null

  for (const input of newMeals) {
    // Case-insensitive exact dedup. limit(1) rather than maybeSingle() — catalog
    // names aren't unique and maybeSingle throws on more than one row.
    const { data: dups, error: dupError } = await supabase
      .from("catalog_meals")
      .select(SELECT_WITH_CATEGORY)
      .ilike("name", escapeLikePattern(input.name))
      .limit(1)

    if (dupError) throw ApiError.badRequest("Failed to check meal", dupError.message)

    if (dups && dups.length > 0) {
      meals.push({ name: input.name, meal: rowToCatalogMeal(dups[0]) })
      continue
    }

    meals.push({ name: input.name, meal: await insertNewMeal(userId, input, categoryId) })
  }

  const outcomes = await Promise.all(aliasUpdates.map(applyAliasUpdate))
  const aliasesUpdated = outcomes.filter(Boolean).length

  return { meals, aliasesUpdated }
}
