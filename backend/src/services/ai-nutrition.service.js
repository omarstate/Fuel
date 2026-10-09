// AI meal estimation via Google Gemini with Search grounding.
//
// Each item the user typed (one comma-separated entry = one meal) is sent to
// Gemini as its own request, so every meal gets its own grounded web lookup.
// The prompt forces an Egypt-first search: use the item as sold in the local
// Egyptian market, and only fall back to the closest regional/global data
// when nothing Egyptian exists.

import { env } from "../config/env.js"
import { ApiError } from "../utils/api-error.js"
import { reconcileNutrition, downgradeConfidence } from "../utils/validate-nutrition.js"

const GEMINI_ENDPOINT = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`

const assertGeminiConfigured = () => {
  if (!env.isGeminiConfigured) {
    throw ApiError.serviceUnavailable(
      "AI estimation is not configured on the server. Set GEMINI_API_KEY in backend/.env."
    )
  }
}

function buildPrompt({ place, item, lang = "en" }) {
  const from = place ? ` from "${place}"` : ""
  const arabicInstruction =
    lang === "ar"
      ? `

Write "name" and "note" in Arabic. Keep brand names in their original Latin script. The JSON keys stay in English, and numeric values stay as digits.`
      : ""
  return `You are a nutrition estimator for a fitness app whose users are primarily in Egypt.

The user ate this single item${from}: "${item}".

Use Google Search to find accurate nutrition facts, and PRIORITIZE the Egyptian market:
1. First, look for the item exactly as sold in Egypt — Egyptian branch menus, Egyptian fast-food portions, local Egyptian brands, and Arabic-language sources. Egyptian portion sizes and recipes can differ from other countries, so prefer local data.
2. Only if no Egyptian data exists, use the closest Middle-East / regional equivalent.
3. Only if that is also unavailable, fall back to global data.

Estimate the nutrition for ONE typical serving of what the user described.

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "name": "concise meal name, e.g. McDonald's Big Mac",
  "servingSize": "human-readable serving, e.g. 1 sandwich (219g)",
  "servingGrams": integer grams of ONE serving, or null if genuinely unknown,
  "calories": integer kcal,
  "protein": integer grams,
  "carbs": integer grams,
  "fat": integer grams,
  "source": "egypt" | "regional" | "global",
  "confidence": "high" | "medium" | "low",
  "note": "one short sentence on the source or any assumption"
}

All macro values must be non-negative integers. If a value is genuinely unknown, give your best reasonable estimate rather than 0.${arabicInstruction}`
}

function extractText(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts
  if (!Array.isArray(parts)) return ""
  return parts
    .map((p) => (typeof p.text === "string" ? p.text : ""))
    .join("")
    .trim()
}

// Gemini sometimes wraps JSON in ```json fences or adds stray prose despite the
// instruction. Pull out the first balanced {...} block and parse that.
function parseEstimate(text) {
  if (!text) return null
  let raw = text.trim()
  const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence) raw = fence[1].trim()
  const start = raw.indexOf("{")
  const end = raw.lastIndexOf("}")
  if (start === -1 || end === -1 || end < start) return null
  try {
    return JSON.parse(raw.slice(start, end + 1))
  } catch {
    return null
  }
}

const clampInt = (value) => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n >= 0 ? n : 0
}

// Positive int or null — the model is told to send null when it can't tell.
const toGrams = (value) => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n > 0 ? n : null
}

const SOURCES = new Set(["egypt", "regional", "global"])
const CONFIDENCE = new Set(["high", "medium", "low"])

// Appended to `note` when the arithmetic checks fired, so the review step says
// why the number moved instead of silently differing from what the model wrote.
const RECONCILED_NOTE = {
  en: "Calories adjusted to match the macros.",
  ar: "تم تعديل السعرات لتطابق الماكروز.",
}
const FLAGGED_NOTE = {
  en: "These numbers look off against the serving size — double-check them.",
  ar: "الأرقام دي مش متسقة مع حجم الحصة — راجعها.",
}

const appendNote = (note, sentence) => (note ? `${note} ${sentence}` : sentence)

async function estimateOne({ place, item, lang = "en" }) {
  let res
  try {
    res = await fetch(`${GEMINI_ENDPOINT(env.GEMINI_MODEL)}?key=${env.GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: buildPrompt({ place, item, lang }) }] }],
        tools: [{ google_search: {} }],
        generationConfig: { temperature: 0.2 },
      }),
    })
  } catch {
    throw ApiError.serviceUnavailable("Couldn't reach the AI service. Try again in a moment.")
  }

  if (!res.ok) {
    let detail
    try {
      detail = (await res.json())?.error?.message
    } catch {
      detail = res.statusText
    }
    if (res.status === 429) {
      throw ApiError.serviceUnavailable("The AI service is rate-limited right now. Try again shortly.")
    }
    throw ApiError.badRequest("AI estimation failed.", detail)
  }

  const payload = await res.json()
  const parsed = parseEstimate(extractText(payload))

  if (!parsed) {
    // Return a soft failure for this item rather than blowing up the whole
    // batch — the user can still fill this one in by hand in the review step.
    return {
      input: item,
      ok: false,
      name: item,
      servingSize: "",
      servingGrams: null,
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      source: null,
      confidence: null,
      note: "Couldn't estimate this item automatically — enter its macros manually.",
    }
  }

  const protein = clampInt(parsed.protein)
  const carbs = clampInt(parsed.carbs)
  const fat = clampInt(parsed.fat)
  const servingGrams = toGrams(parsed.servingGrams)

  // Cross-check the model's own numbers before the user ever sees them: macros
  // beat the stated calories, and anything that fails drops a confidence notch
  // so the review step doesn't present a wobbly estimate as "high".
  const { calories, adjusted, flags } = reconcileNutrition({
    calories: parsed.calories,
    protein,
    carbs,
    fat,
    servingGrams,
  })

  let confidence = CONFIDENCE.has(parsed.confidence) ? parsed.confidence : null
  let note = typeof parsed.note === "string" ? parsed.note.trim() : ""

  if (adjusted || flags.length > 0) {
    confidence = downgradeConfidence(confidence)
    const suffix = adjusted ? RECONCILED_NOTE : FLAGGED_NOTE
    note = appendNote(note, suffix[lang] ?? suffix.en)
  }

  return {
    input: item,
    ok: true,
    name: typeof parsed.name === "string" && parsed.name.trim() ? parsed.name.trim() : item,
    servingSize: typeof parsed.servingSize === "string" ? parsed.servingSize.trim() : "",
    servingGrams,
    calories,
    protein,
    carbs,
    fat,
    source: SOURCES.has(parsed.source) ? parsed.source : null,
    confidence,
    note,
  }
}

/**
 * Estimate nutrition for a batch of meal items.
 * @param {{ place?: string, items: string[], lang?: "en" | "ar" }} input
 * @returns {Promise<Array>} one result per item, in input order
 */
export const estimateMeals = async ({ place, items, lang = "en" }) => {
  assertGeminiConfigured()
  return Promise.all(items.map((item) => estimateOne({ place, item, lang })))
}
