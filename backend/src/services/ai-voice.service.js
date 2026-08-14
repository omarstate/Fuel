// Voice meal logging — parse a spoken transcript into loggable items.
//
// The app transcribes speech on-device and posts the text here. Newer builds
// race TWO recognizers (one assuming Egyptian Arabic, one assuming English)
// over the SAME audio and send BOTH readings in `transcripts`; the model — far
// better than any on-device confidence score at telling real speech from
// lookalike gibberish in the wrong language — decides what was actually said.
// When only `transcript` arrives (old builds, typed fallback) the prompt keeps
// its original single-transcription shape.
//
// ONE Gemini call does everything: it reconstructs the real utterance, extracts
// each food + quantity + the target meal section, matches each item against the
// catalog (names + the `aliases` column that bridges Arabic speech to English
// catalog names), AND estimates Egypt-first macros inline — from model
// knowledge — for whatever it could not match.
//
// That single call replaced a parse call plus one web-grounded call per
// unmatched item. The old shape routinely took 30–60s for a three-item
// utterance and its retry ladder still produced zero-macro rows whenever the
// free-tier grounding quota ran out; this one answers in a couple of seconds.
// There is deliberately NO web search in this flow, so estimates always carry
// `sourceUrl: null`. The response contract to the app is otherwise unchanged:
// same `kind: "catalog" | "estimate"` items, same fields.
//
// This service NEVER writes log rows: the app inserts those straight into
// Supabase under RLS. `commitVoiceLog` persists catalog changes only.

import { supabase } from "../config/supabase.js"
import { rowToCatalogMeal } from "../models/catalog-meal.model.js"
import { generateJson } from "./gemini.client.js"
import { ApiError } from "../utils/api-error.js"
import { matchMealName, deriveFactor } from "../utils/match-meal-name.js"
import {
  voiceParseSchema,
  voiceParsedItemSchema,
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
// Step 2 — the one prompt: parse + match + estimate
// -------------------------------------------------------------------------

/**
 * Pick the two rival readings of one utterance out of the request's
 * `transcripts` array. Returns null unless there are genuinely two entries in
 * DISTINCT languages — anything less and the prompt stays single-transcript.
 * @returns {{ ar: string, en: string } | null}
 */
const dualReadings = (transcripts) => {
  if (!Array.isArray(transcripts) || transcripts.length < 2) return null
  const ar = transcripts.find((entry) => entry?.lang === "ar")?.text?.trim()
  const en = transcripts.find((entry) => entry?.lang === "en")?.text?.trim()
  if (!ar || !en) return null
  return { ar, en }
}

const PARSE_PROMPT = ({ transcript, readings, catalogLines, catalogCount, lang = "en" }) => {
  // Whatever the user's device decided, "name"/"servingSize"/"note" follow the
  // language actually spoken; `lang` only breaks the tie on a mixed utterance.
  // Wording mirrors the old per-item estimate prompt, so Arabic replies keep
  // reading like an Egyptian wrote them.
  const languageInstruction = `

LANGUAGE. Write "name", "servingSize" and "note" in the language the user actually spoke — Egyptian-flavoured Arabic if the utterance is Arabic, English otherwise; if the utterance genuinely mixes both, use ${lang === "ar" ? "Arabic" : "English"}. Always fill in "nameAr" with a concise Arabic name regardless. Keep brand names in their original Latin script. The JSON keys stay in English, and every number stays as Western digits.`

  // Two rival readings of the same audio → the model reconstructs the real
  // utterance first (TASK 0). One reading only → the original opening block.
  const openingBlock = readings
    ? `The user spoke ONE utterance out loud. The SAME audio was transcribed twice by two on-device speech recognizers — one assuming Egyptian Arabic, one assuming English:

READING A (Arabic recognizer):
"""
${readings.ar}
"""

READING B (English recognizer):
"""
${readings.en}
"""

TASK 0 — REAL UTTERANCE. Decide what was actually said. Usually one reading is the real speech and the other is lookalike gibberish in the wrong language; when the user mixed languages mid-sentence, each reading may capture the words of its own language — combine them. Do every task below against the REAL utterance you reconstructed, never against the gibberish reading.`
    : `The user spoke out loud and this is the on-device transcription:
"""
${transcript}
"""`

  return `You are the parser behind VOICE meal logging in a nutrition app. ${openingBlock}

The users are primarily in EGYPT. They speak colloquial EGYPTIAN ARABIC, English, or both mixed inside one sentence. Transcription is imperfect — read through small mis-hearings instead of taking them literally.

Egyptian colloquial you are expected to understand (not exhaustive):
- Numbers as words: واحد/واحدة = 1, اتنين = 2, تلاتة/تلات = 3, اربعة/اربع = 4, خمسة/خمس = 5, ستة = 6, سبعة = 7, تمانية = 8, تسعة = 9, عشرة = 10; نص = a half (0.5), ربع = a quarter (0.25), تلت = a third. Arabic-Indic digits (٣) mean the same as Western ones (3).
- Portions and containers: كوباية/كوب = a cup or glass, معلقة = a spoon, معلقة كبيرة = tablespoon, معلقة صغيرة = teaspoon, رغيف = one loaf of baladi bread, شريحة = a slice, حبة = one piece, حبتين = two pieces, طبق = a plate, علبة = a can/tub, كيس = a bag/packet, نص كيلو = half a kilo.
- Foods: فول = fava beans (foul), طعمية/فلافل = falafel, عيش بلدي = baladi bread, عيش فينو = fino bread, عيش توست/توست = toast, بيض مسلوق = boiled eggs, بيض مقلي = fried eggs, جبنة قريش = karish cheese, جبنة بيضاء = white cheese, لبن = milk, زبادي = yoghurt, فراخ = chicken, لحمة = beef, أرز = rice, مكرونة = pasta, بطاطس = potatoes, كشري = koshari, ملوخية = molokhia, محشي = stuffed vegetables, شاورما, فتة, بسبوسة, مانجو = mango, تمر = dates.

TASK 1 — ITEMS. Extract every DISTINCT food or drink the user says they ate or drank, in the order spoken, keeping the quantity and unit AS SPOKEN. Never merge two different foods into one item. Never break one dish down into its ingredients. Never invent an item that was not said. Ignore filler and non-food words ("ضيفهم على", "سجّل", "log this", "add", "please").

TASK 2 — MEAL SECTION. Only if the user actually says which meal it belongs to, map it: فطار/الفطار/فطور/breakfast → "breakfast"; غدا/الغدا/غداء/lunch → "lunch"; عشا/العشا/عشاء/dinner → "dinner"; سناك/تصبيرة/وجبة خفيفة/snack → "snack". If they do not say, return null — never guess from the food itself.

TASK 3 — CATALOG MATCH. The app's meal catalog is below, one compact JSON object per line: {"id","name","aliases","servingSize"}. For EVERY item, scan the whole list before deciding — do not give up early. Set "catalogId" to an entry's id when the item is genuinely the SAME food:
- Colloquial Egyptian names count (بيض مسلوق = "Boiled Eggs", عيش توست = "Toast", فول = "Foul Medames"), as does anything in an entry's "aliases".
- Singular/plural and word-order differences count ("boiled egg" = "3 baladi eggs boiled").
- A generic item DOES match a branded catalog entry of the same basic food when no generic entry exists ("toast" → "Rich Bake protein toast") — this is the user's personal catalog, so the branded entry is almost certainly what they mean.
- A different preparation or a mere category cousin is NOT a match (فراخ مشوية is not "Fried Chicken"), a qualified item must keep its qualifier ("skimmed milk" is not "full-fat milk"), and a plain food is NOT a composed product that merely contains it ("a glass of milk" / كوباية لبن is NOT a protein shake made with milk).
When genuinely torn, return null. Only ever use an id that appears in the list below.

TASK 4 — FACTOR. When you matched an entry, set "factor" to (the amount the user spoke) ÷ (that entry's "servingSize"). Examples: spoken "3 eggs" against servingSize "1 egg (50g)" → 3; spoken "3 eggs" against servingSize "2 eggs" → 1.5; spoken "200ml" against "1 cup (240ml)" → 0.83; spoken "نص رغيف" against "1 loaf" → 0.5; spoken with no amount → 1. Always divide by the NUMBER OF UNITS in the serving size, never default to 1 when the counts differ. If the entry has no servingSize or the ratio is not workable, return null.

TASK 5 — MACROS, for items where you set "catalogId" to null ONLY. Estimate the nutrition from your own knowledge — you have no web access — prioritizing how the food is typically sold or cooked in EGYPT: Egyptian brands and branch menus, baladi portions, Egyptian home recipes. Use Middle-East / regional data only when there is no Egyptian equivalent, and global data only after that.
Pick ONE natural base serving and give macros for THAT base serving only:
- countable foods → exactly ONE piece: "1 slice (~25g)", "1 egg (50g)", "1 رغيف بلدي (~90g)"
- foods measured in ml or g → a round base of "100 ml" or "100 g"
- plated/composed dishes → one typical Egyptian serving, named clearly ("1 bowl (~350g)")
Then set "factor" = (the amount the user spoke) ÷ (your base serving), exactly the rule from TASK 4: "3 slices" against "1 slice" → 3; "200ml" against "100 ml" → 2; "نص رغيف" against "1 رغيف" → 0.5; no amount spoken → 1.
The macros are non-negative integers covering the BASE serving, NEVER the whole spoken amount — the app multiplies by "factor" itself. If a value is genuinely unknown, give your best reasonable estimate rather than 0. "ranges" bands the base serving too, with min <= point <= max; return null only when the numbers are solid enough that a band adds nothing. "note" is one short sentence on any assumption you made.
For items you DID match to the catalog, set "servingSize", "calories", "protein", "carbs", "fat", "ranges" and "note" all to null — the app takes those from the catalog entry.

CATALOG (${catalogCount} entries):
${catalogLines}

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "mealType": "breakfast" | "lunch" | "dinner" | "snack" | null,
  "items": [
    {
      "spoken": "the words the user used for this item, in the original language",
      "name": "concise name in the language the LANGUAGE rule below picks, e.g. Boiled Eggs or بيض مسلوق",
      "nameAr": "concise Arabic name, e.g. بيض مسلوق",
      "quantity": number | null,
      "unit": "unit as spoken, e.g. egg, slice, ml, رغيف" | null,
      "catalogId": "an id from the catalog above" | null,
      "factor": number | null,
      "confidence": "high" | "medium" | "low",
      "servingSize": "the base serving the macros below cover, e.g. 1 egg (50g)" | null,
      "calories": integer kcal for the base serving | null,
      "protein": integer grams | null,
      "carbs": integer grams | null,
      "fat": integer grams | null,
      "ranges": {"calories":[min,max],"protein":[min,max],"carbs":[min,max],"fat":[min,max]} | null,
      "note": "one short sentence on any assumption you made" | null
    }
  ]
}

Return at most ${MAX_VOICE_ITEMS} items. If the transcript mentions no food or drink at all, return {"mealType": null, "items": []}.${languageInstruction}`
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

// Used when the model returns an unmatched item whose macros are unusable —
// the review sheet then offers manual entry instead of a zero-macro surprise.
const softFailEstimate = (item, lang) => {
  const note = MANUAL_ENTRY_NOTE
  return {
    kind: "estimate",
    ok: false,
    spoken: item.spoken,
    quantity: item.quantity,
    unit: item.unit,
    name: item.name || item.spoken,
    servingSize: "",
    factor: 1,
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    ranges: null,
    sourceUrl: null,
    confidence: null,
    note: note[lang] ?? note.en,
  }
}

// -------------------------------------------------------------------------
// Endpoint A — parse a transcript (writes nothing)
// -------------------------------------------------------------------------

/**
 * @param {{
 *   transcript: string,
 *   lang?: "en" | "ar",
 *   transcripts?: { lang: "en" | "ar", text: string }[],
 * }} input `transcripts` carries both recognizers' readings of the same audio
 *   when the app has them; `transcript` is the app's own pick (and the only
 *   input old builds send).
 * @returns {Promise<{ mealType: string|null, items: object[] }>} items in spoken order
 */
export const parseVoiceLog = async ({ transcript, lang = "en", transcripts }) => {
  const candidates = await fetchCandidates()
  const candidateIds = new Set(candidates.map((row) => row.id))

  // One call for everything — pick the real reading, parse, match and estimate.
  // JSON mode keeps the reply clean and thinking is off, which is what buys the
  // 2–4s latency.
  const { data } = await generateJson({
    useSearch: false,
    temperature: 0,
    json: true,
    thinkingBudget: 0,
    prompt: PARSE_PROMPT({
      transcript,
      readings: dualReadings(transcripts),
      catalogLines: candidates.map(catalogLine).join("\n"),
      catalogCount: candidates.length,
      lang,
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
    let catalogId = item.catalogId && candidateIds.has(item.catalogId) ? item.catalogId : null
    // The model now returns a factor for unmatched items too (spoken amount ÷
    // its own base serving), so it is worth keeping either way.
    let factor = clampFactor(item.factor)

    // The model is occasionally lazy about matching. Deterministic token
    // containment against names + aliases catches what it missed, and works
    // out the multiplier from the quantity it DID parse. Only when the model
    // ALSO skipped the estimate, though — when it returned macros it actively
    // decided the item is not in the catalog (e.g. plain milk vs a milk-based
    // protein shake), and single-token containment must not override that.
    // Zero counts as an estimate (water, diet soda) — same rule as the usable
    // check below, or a 0-kcal item falls through to the token matcher.
    const modelEstimated =
      item.calories != null && Number.isFinite(Number(item.calories)) && Number(item.calories) >= 0
    if (!catalogId && !modelEstimated) {
      const fallbackId = matchMealName([item.name, item.nameAr, spoken].filter(Boolean), candidates)
      if (fallbackId) {
        catalogId = fallbackId
        const row = candidates.find((candidate) => candidate.id === fallbackId)
        factor = clampFactor(deriveFactor(item.quantity ?? null, item.unit ?? null, row?.serving_size ?? null))
      }
    }

    items.push({
      spoken,
      name: item.name,
      nameAr: item.nameAr ?? null,
      quantity: item.quantity ?? null,
      unit: item.unit ?? null,
      catalogId,
      factor,
      confidence: item.confidence ?? null,
      // Only meaningful when catalogId stays null — see the estimate branch.
      servingSize: item.servingSize ?? null,
      calories: item.calories ?? null,
      protein: item.protein ?? null,
      carbs: item.carbs ?? null,
      fat: item.fat ?? null,
      ranges: item.ranges ?? null,
      note: item.note ?? null,
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

  // Both kinds resolve locally now: catalog matches from the rows just fetched,
  // estimates from the very same Gemini reply. No further network calls.
  const results = items.map((item) => {
    const meal = item.catalogId ? mealsById.get(item.catalogId) : null
    if (meal) {
      return {
        kind: "catalog",
        spoken: item.spoken,
        quantity: item.quantity,
        unit: item.unit,
        factor: item.factor,
        meal,
      }
    }

    // A calorie figure is the one number that has to be there; without it the
    // row would be a zero-macro surprise, so hand the user manual entry instead.
    // Zero itself is a legitimate answer (water, diet soda) — only a MISSING
    // or negative value means the model skipped TASK 5.
    const calories = Number(item.calories)
    if (item.calories == null || !Number.isFinite(calories) || calories < 0) {
      return softFailEstimate(item, lang)
    }

    return {
      kind: "estimate",
      ok: true,
      spoken: item.spoken,
      quantity: item.quantity,
      unit: item.unit,
      name: item.name || item.spoken,
      servingSize: item.servingSize?.trim() ?? "",
      factor: clampFactor(item.factor),
      calories: roundInt(item.calories),
      protein: roundInt(item.protein),
      carbs: roundInt(item.carbs),
      fat: roundInt(item.fat),
      ranges: normalizeRanges(item.ranges),
      // This flow never searches the web, so there is never a source to cite.
      sourceUrl: null,
      confidence: item.confidence ?? null,
      note: item.note?.trim() ?? "",
    }
  })

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
