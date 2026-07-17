// AI nutrition-label extraction via Google Gemini (multimodal).
//
// The user photographs a packaged product's Nutrition Facts panel; Gemini reads
// the panel and returns structured macros. Unlike ai-nutrition.service.js this
// does NOT use Search grounding — every fact is on the label in the photo. The
// hard parts are all in the prompt: Egyptian/EU labels are usually per-100g
// (US labels per-serving), values may be in Arabic, and energy is often printed
// in kilojoules. The client shows a review step, so a misread digit is caught
// by the user before anything is logged.

import { generateJson } from "./gemini.client.js"

const PROMPT = `You are a nutrition-label reader for a fitness app whose users are primarily in Egypt.

You are given a PHOTO of a packaged food product. It most likely shows the Nutrition Facts panel ("Nutrition Information", "Nutrition Facts", or the Arabic "القيمة الغذائية" / "المعلومات الغذائية"). Read the printed values off the label — do NOT guess from the product name or your own knowledge; only report what the label states.

Follow these rules carefully:
1. BASIS: Labels state values per 100 g/ml OR per serving/portion — sometimes both in two columns.
   - If only one basis is printed, use it and report which one.
   - If BOTH are printed, report the PER-SERVING column and set basis to "per_serving".
   - Report basis as "per_100g" (covers per 100 g and per 100 ml) or "per_serving".
2. ENERGY: If energy is given in kilojoules (kJ) only, convert to kilocalories: kcal = kJ / 4.184. If both kJ and kcal are shown, use the kcal value. Always return calories in kcal.
3. ARABIC: The label may be in Arabic, English, or both. Read either. Return all field names and the product name in English.
4. SERVING SIZE: If a serving/portion size is printed (e.g. "30 g", "1 cup (240 ml)", "حصة 30 جم"), capture it in servingSize, and put the numeric grams (or ml) of one serving in servingGrams when you can read it. If no serving size is printed, use "" and null.
5. PRODUCT NAME: A close-up of the facts panel usually does NOT show the brand/product name. Only set name if the product name is clearly visible in the photo; otherwise use null. Never invent a brand.
6. If the photo is not a readable nutrition label (blurry, wrong side of the pack, not food), set readable to false and leave macros at 0.

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "readable": true | false,
  "name": "product name in English, or null if not visible",
  "basis": "per_100g" | "per_serving",
  "servingSize": "human-readable serving as printed, or empty string",
  "servingGrams": number of grams/ml in one serving, or null,
  "calories": integer kcal on the stated basis,
  "protein": integer grams,
  "carbs": integer grams,
  "fat": integer grams,
  "confidence": "high" | "medium" | "low",
  "note": "one short sentence: what basis/units you read, or why it was unreadable"
}

All macro values must be non-negative integers on the stated basis.`

const clampInt = (value) => {
  const n = Math.round(Number(value))
  return Number.isFinite(n) && n >= 0 ? n : 0
}

const BASIS = new Set(["per_100g", "per_serving"])
const CONFIDENCE = new Set(["high", "medium", "low"])

const toNullableString = (value) =>
  typeof value === "string" && value.trim() ? value.trim() : null

const toPositiveNumber = (value) => {
  const n = Number(value)
  return Number.isFinite(n) && n > 0 ? n : null
}

// Soft failure — same idea as ai-nutrition.service.js: hand back a fillable
// blank so the review step can ask the user to retake or enter values by hand,
// rather than throwing and losing their photo.
const unreadable = (note) => ({
  ok: false,
  readable: false,
  name: null,
  basis: "per_serving",
  servingSize: "",
  servingGrams: null,
  calories: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
  confidence: null,
  note: note || "Couldn't read this label. Retake the photo or enter the values manually.",
})

/**
 * Extract nutrition facts from a photo of a product label.
 * @param {{ image: string, mimeType: string }} input  `image` is raw base64.
 * @returns {Promise<object>} normalized, validated extraction (never throws for
 *   a bad photo — returns a soft-failure shape instead).
 */
export const extractLabel = async ({ image, mimeType }) => {
  let result
  try {
    result = await generateJson({
      prompt: PROMPT,
      image: { mimeType, data: image },
      useSearch: false,
      temperature: 0.1,
    })
  } catch {
    return unreadable("The AI service didn't respond. Try again in a moment.")
  }

  const parsed = result?.data
  if (!parsed || typeof parsed !== "object" || parsed.readable === false) {
    return unreadable(toNullableString(parsed?.note))
  }

  return {
    ok: true,
    readable: true,
    name: toNullableString(parsed.name),
    basis: BASIS.has(parsed.basis) ? parsed.basis : "per_serving",
    servingSize: typeof parsed.servingSize === "string" ? parsed.servingSize.trim() : "",
    servingGrams: toPositiveNumber(parsed.servingGrams),
    calories: clampInt(parsed.calories),
    protein: clampInt(parsed.protein),
    carbs: clampInt(parsed.carbs),
    fat: clampInt(parsed.fat),
    confidence: CONFIDENCE.has(parsed.confidence) ? parsed.confidence : null,
    note: typeof parsed.note === "string" ? parsed.note.trim() : "",
  }
}
