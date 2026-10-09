import { supabase } from "../config/supabase.js"
import { rowToCatalogMeal } from "../models/catalog-meal.model.js"
import { generateJson } from "./gemini.client.js"
import { getProfile } from "./profile.service.js"
import { computeStreak } from "../utils/compute-streak.js"
import { rankMealsForRemaining } from "../utils/score-meals.js"
import { mealTokens } from "../utils/match-meal-name.js"
import { reconcileNutrition, downgradeConfidence } from "../utils/validate-nutrition.js"
import { aiMealArraySchema, normalizeAiMeal, insightsSchema } from "../validators/ai.validator.js"
import { ApiError } from "../utils/api-error.js"

const SELECT_WITH_CATEGORY = "*, meal_categories(id, name, slug)"

// Frontend DEFAULT_TARGETS mirror — used when the user has no profile yet.
const DEFAULT_TARGET_CALORIES = 2200
const DEFAULT_TARGET_PROTEIN = 165

const utcDayKey = (value = new Date()) => {
  const d = new Date(value)
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(
    d.getUTCDate()
  ).padStart(2, "0")}`
}

// -------------------------------------------------------------------------
// AI meal lookup
// -------------------------------------------------------------------------

const LOOKUP_PROMPT = (query, lang = "en") => `You are a nutrition data assistant. The user wants to log the following food (may contain MULTIPLE items):
"${query}"
Use Google Search to find nutrition facts for EACH distinct item. Prefer the brand's OFFICIAL website or official menu/nutrition PDF; use reputable databases only when no official source exists.
Reply with ONLY a JSON array (no prose, no markdown), each element:
{"name": string (canonical, include brand, e.g. "McDonald's Big Mac"),
 "brand": string|null, "servingSize": string|null (e.g. "1 burger (219g)"),
 "servingGrams": integer grams of ONE serving, or null if genuinely unknown,
 "calories": number, "protein": number, "carbs": number, "fat": number,   // grams, best point estimate
 "confidence": "official" | "estimate",   // "official" ONLY if values come from the brand's own site
 "ranges": {"calories":[min,max],"protein":[min,max],"carbs":[min,max],"fat":[min,max]} | null,
    // REQUIRED when confidence is "estimate", null when "official"
 "sourceUrl": string|null, "sourceTitle": string|null}${
   lang === "ar"
     ? `
Write "name" and "servingSize" in Arabic. If the user's query is already in Arabic, keep the meal name close to how they wrote it. Keep brand names in their original Latin script. JSON keys stay in English; numbers stay as digits.`
     : ""
 }`

// Look up the ai-discovered category once. Falls back to the first category if
// the 0008 seed hasn't run yet; returns null only if there are no categories.
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

// How many ilike candidates we pull before filtering them by token containment.
const PRECHECK_CANDIDATES = 25
// How many pre-check hits we hand back, matching the old limit(5).
const PRECHECK_RESULTS = 5

// A serving size that already states grams: "1 burger (219g)", "حصة 30 جم".
// The `g` must not be the first letter of a word ("1 grilled breast").
const SERVING_HAS_GRAMS = /[0-9٠-٩]\s*(?:g(?![a-zA-Z])|جم|جرام)/

/**
 * Does this catalog row actually answer the query, or does it merely contain it
 * as a substring? `%coffee%` matches "Coffee cake"; token containment doesn't.
 * Every significant query token must appear in the row's name/alias tokens.
 */
const rowAnswersQuery = (row, queryTokens) => {
  const candidateTokens = mealTokens(
    [row.name, ...(Array.isArray(row.aliases) ? row.aliases : [])].join(" ")
  )
  for (const token of queryTokens) {
    if (!candidateTokens.has(token)) return false
  }
  return true
}

/**
 * Arithmetic sanity pass over one normalized AI item. An "official" number that
 * fails its own Atwater check isn't official — a brand's own page would add up —
 * so a flagged item is demoted and keeps/gains a range instead of posing as
 * fact. Ranges are widened rather than clipped so `min <= point <= max` holds.
 */
const reconcileLookupItem = (item) => {
  const { calories, adjusted, flags } = reconcileNutrition({
    calories: item.calories,
    protein: item.protein,
    carbs: item.carbs,
    fat: item.fat,
    servingGrams: item.servingGrams ?? null,
  })

  const suspect = adjusted || flags.length > 0
  const confidence = suspect ? downgradeConfidence(item.confidence) : item.confidence

  let ranges = item.ranges
  if (ranges && ranges.calories) {
    const [min, max] = ranges.calories
    if (calories < min || calories > max) {
      ranges = { ...ranges, calories: [Math.min(min, calories), Math.max(max, calories)] }
    }
  }

  // The model often writes "1 cup" with no weight; folding the grams it DID
  // report into the text keeps portion maths possible for whoever logs this.
  let servingSize = item.servingSize ?? null
  if (item.servingGrams != null && item.servingGrams > 0) {
    servingSize = servingSize && SERVING_HAS_GRAMS.test(servingSize)
      ? servingSize
      : servingSize
        ? `${servingSize} (${item.servingGrams}g)`
        : `${item.servingGrams}g`
  }

  return { ...item, calories, confidence, ranges, servingSize }
}

export const lookupMeals = async (userId, query, lang = "en") => {
  // 1. Pre-check the catalog so we never duplicate an existing meal or spend a
  //    Gemini call when we already have a trustworthy match. Two filters, both
  //    needed: ilike is a substring test (so "tea" matches "steak"), and an
  //    ai_source of 'estimate' is one user's AI guess, not an answer — the same
  //    rule the barcode cache applies to 'client'-sourced rows, which never
  //    block a live fetch. Only null (hand-entered) or 'official' rows short-
  //    circuit; otherwise one early hallucination would be everyone's permanent
  //    answer, with no path back to a real source.
  const { data: existing, error: existingError } = await supabase
    .from("catalog_meals")
    .select(SELECT_WITH_CATEGORY)
    .ilike("name", `%${query}%`)
    .limit(PRECHECK_CANDIDATES)

  if (existingError) throw ApiError.badRequest("Failed to search meals", existingError.message)

  const queryTokens = mealTokens(query)
  const matches =
    queryTokens.size > 0 ? (existing ?? []).filter((row) => rowAnswersQuery(row, queryTokens)) : []
  const verified = matches.filter((row) => row.ai_source == null || row.ai_source === "official")
  // Unverified hits still matter: they're the rows a fresh official answer gets
  // to overwrite in step 3a, instead of sitting next to a near-duplicate.
  const unverified = matches.filter((row) => row.ai_source === "estimate")

  if (verified.length > 0) {
    return {
      items: verified
        .slice(0, PRECHECK_RESULTS)
        .map((row) => ({ meal: rowToCatalogMeal(row), created: false })),
      usedAi: false,
    }
  }

  // 2. Ask Gemini (grounded with Google Search).
  const { data, sources } = await generateJson({
    useSearch: true,
    prompt: LOOKUP_PROMPT(query, lang),
  })

  const parsed = aiMealArraySchema.parse(data)
  const categoryId = await getAiCategoryId()
  const fallbackSourceUri = sources[0]?.uri ?? null

  const items = []
  for (const raw of parsed) {
    const item = reconcileLookupItem(normalizeAiMeal(raw))

    // 3a. Per-item dedup by exact (case-insensitive) name. The unverified rows
    // from step 1 are checked first — they came back from the same search, so a
    // name hit there saves a round trip. limit(1) rather than maybeSingle() —
    // catalog names aren't unique, and maybeSingle throws on >1.
    let dup = unverified.find((row) => row.name.toLowerCase() === item.name.toLowerCase()) ?? null

    if (!dup) {
      const { data: dups, error: dupError } = await supabase
        .from("catalog_meals")
        .select(SELECT_WITH_CATEGORY)
        .ilike("name", item.name)
        .limit(1)

      if (dupError) throw ApiError.badRequest("Failed to check meal", dupError.message)
      dup = dups?.[0] ?? null
    }

    if (dup) {
      // An 'estimate' row is a placeholder for exactly this moment: a verified
      // official answer replaces it in place, so every log already pointing at
      // that catalog id silently gets the real numbers (and loses its range).
      if (dup.ai_source === "estimate" && item.confidence === "official") {
        const { data: upgraded, error: upgradeError } = await supabase
          .from("catalog_meals")
          .update({
            serving_size: item.servingSize ?? dup.serving_size,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            ai_source: "official",
            source_url: item.sourceUrl ?? fallbackSourceUri,
            macro_ranges: null,
          })
          .eq("id", dup.id)
          .select(SELECT_WITH_CATEGORY)
          .single()

        if (upgradeError) throw ApiError.badRequest("Failed to update meal", upgradeError.message)

        items.push({ meal: rowToCatalogMeal(upgraded), created: false })
        continue
      }

      items.push({ meal: rowToCatalogMeal(dup), created: false })
      continue
    }

    // 3b. Persist a new catalog meal.
    const insertRow = {
      name: item.name,
      description: null,
      category_id: categoryId,
      serving_size: item.servingSize ?? null,
      calories: item.calories,
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
      created_by: userId,
      ai_source: item.confidence,
      source_url: item.sourceUrl ?? fallbackSourceUri,
      macro_ranges: item.confidence === "estimate" ? item.ranges : null,
    }

    const { data: inserted, error: insertError } = await supabase
      .from("catalog_meals")
      .insert(insertRow)
      .select(SELECT_WITH_CATEGORY)
      .single()

    if (insertError) throw ApiError.badRequest("Failed to save meal", insertError.message)

    items.push({ meal: rowToCatalogMeal(inserted), created: true })
  }

  return { items, usedAi: true }
}

// -------------------------------------------------------------------------
// AI coach insights
// -------------------------------------------------------------------------

const daysAgoIso = (days) => new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString()

const INSIGHTS_PROMPT = (factsJson, lang = "en") => `You are a friendly, concise fitness coach. Given the user's FACTS (JSON), write a short, encouraging daily summary. No medical claims, no shaming tone.
FACTS:
${factsJson}
Reply with ONLY JSON (no prose, no markdown):
{"headline": string (<= 90 chars, punchy, mention the streak if it's alive),
 "insights": [{"title": string, "body": string (<= 220 chars)}]  (2-4 items covering: intake vs target, protein, workout consistency, recent trend),
 "tips": [string]  (2-3 short actionable tips for today)}${
   lang === "ar"
     ? `
Write the "headline", every "title"/"body", and every "tips" string in Modern Standard Arabic with an encouraging, friendly Egyptian-appropriate tone. Keep the JSON keys in English. Numbers may stay as Western digits.`
     : ""
 }`

const gatherFacts = async (userId) => {
  const [mealsRes, workoutsRes, mealsWideRes, workoutsWideRes, profile] = await Promise.all([
    supabase
      .from("meals")
      .select("logged_at, calories, protein")
      .eq("user_id", userId)
      .gte("logged_at", daysAgoIso(14)),
    supabase
      .from("workout_sessions")
      .select("started_at, status, duration_seconds")
      .eq("user_id", userId)
      .gte("started_at", daysAgoIso(14)),
    supabase
      .from("meals")
      .select("logged_at")
      .eq("user_id", userId)
      .gte("logged_at", daysAgoIso(90)),
    supabase
      .from("workout_sessions")
      .select("started_at")
      .eq("user_id", userId)
      .gte("started_at", daysAgoIso(90)),
    getProfile(userId).catch(() => null),
  ])

  if (mealsRes.error) throw ApiError.badRequest("Failed to load meals", mealsRes.error.message)
  if (workoutsRes.error)
    throw ApiError.badRequest("Failed to load workouts", workoutsRes.error.message)

  const mealRows = mealsRes.data ?? []
  const workoutRows = workoutsRes.data ?? []

  // Aggregate meals per UTC day.
  const perDayMeals = {}
  for (const row of mealRows) {
    const key = utcDayKey(row.logged_at)
    if (!perDayMeals[key]) perDayMeals[key] = { kcal: 0, protein: 0, entries: 0 }
    perDayMeals[key].kcal += row.calories ?? 0
    perDayMeals[key].protein += row.protein ?? 0
    perDayMeals[key].entries += 1
  }

  // Aggregate workouts per UTC day.
  const perDayWorkouts = {}
  for (const row of workoutRows) {
    const key = utcDayKey(row.started_at)
    if (!perDayWorkouts[key]) perDayWorkouts[key] = { count: 0, durationSeconds: 0 }
    perDayWorkouts[key].count += 1
    perDayWorkouts[key].durationSeconds += row.duration_seconds ?? 0
  }

  const targetCalories = profile?.targetCalories ?? DEFAULT_TARGET_CALORIES
  const targetProtein = profile?.targetProtein ?? DEFAULT_TARGET_PROTEIN

  // Streak over the union of meal + workout activity days (last 90d).
  const activityDates = [
    ...(mealsWideRes.data ?? []).map((r) => r.logged_at),
    ...(workoutsWideRes.data ?? []).map((r) => r.started_at),
  ]
  const streak = computeStreak(activityDates)

  const mealDayCount = Object.keys(perDayMeals).length
  const avgCalories = mealDayCount
    ? Math.round(
        Object.values(perDayMeals).reduce((sum, d) => sum + d.kcal, 0) / mealDayCount
      )
    : 0
  const avgProtein = mealDayCount
    ? Math.round(
        Object.values(perDayMeals).reduce((sum, d) => sum + d.protein, 0) / mealDayCount
      )
    : 0
  const workoutDayCount = Object.keys(perDayWorkouts).length

  return {
    facts: {
      hasProfile: Boolean(profile),
      note: profile ? null : "no targets set — using default 2200 kcal / 165g protein",
      streak,
      targetCalories,
      targetProtein,
      last14Days: {
        daysLogged: mealDayCount,
        avgCaloriesPerLoggedDay: avgCalories,
        avgProteinPerLoggedDay: avgProtein,
        workoutDays: workoutDayCount,
        totalWorkouts: workoutRows.length,
      },
    },
    streak,
    targetCalories,
    targetProtein,
  }
}

export const getInsights = async (userId, { refresh = false, lang = "en" } = {}) => {
  const todayKey = utcDayKey()

  if (!refresh) {
    const { data: cached } = await supabase
      .from("ai_insights")
      .select("content")
      .eq("user_id", userId)
      .eq("day", todayKey)
      .maybeSingle()

    // Only reuse the cached narrative when it matches the requested language.
    // Rows written before this feature carry no `lang` — treat those as "en".
    if (cached?.content && (cached.content.lang ?? "en") === lang) {
      return { ...cached.content, day: todayKey, cached: true }
    }
  }

  const { facts, streak, targetCalories, targetProtein } = await gatherFacts(userId)

  const { data, modelUsed } = await generateJson({
    useSearch: false,
    temperature: 0.4,
    prompt: INSIGHTS_PROMPT(JSON.stringify(facts), lang),
  })

  const narrative = insightsSchema.parse(data)
  // Stamp the language into the cached content so a later request in the other
  // language regenerates instead of serving mismatched prose.
  const cachedContent = { ...narrative, lang }

  // Upsert the cache (best-effort — a failed write shouldn't break the response).
  await supabase
    .from("ai_insights")
    .upsert(
      { user_id: userId, day: todayKey, content: cachedContent, model: modelUsed },
      { onConflict: "user_id,day" }
    )

  return {
    ...narrative,
    day: todayKey,
    facts: { streak, targetCalories, targetProtein },
    cached: false,
  }
}

// -------------------------------------------------------------------------
// AI meal suggestions ("what should I eat next?")
// -------------------------------------------------------------------------

// Below this many remaining calories we treat the day as filled — there's
// nothing meaningful left to suggest against.
const SUGGEST_MIN_CALORIES = 50

// How many DB candidates and shortlist meals we work with.
const CANDIDATE_LIMIT = 200
const SHORTLIST_MAX = 12
const SUGGEST_COUNT = 3

// Reason text is generated from the actual numbers, not an LLM call — meal
// suggestions run on every "remaining macros" bucket change (effectively every
// time the user logs food), which made a live Gemini call per log impractical
// on a free-tier quota. The ranking was already deterministic (score-meals.js);
// this just describes that ranking in the same numeric style Gemini used.
const describeFit = (meal, remaining, lang = "en") => {
  const kcalLeft = Math.max(remaining.calories - meal.calories, 0)
  const closeCalories = Math.abs(meal.calories - remaining.calories) <= Math.max(remaining.calories * 0.15, 50)
  const closeProtein = Math.abs(meal.protein - remaining.protein) <= Math.max(remaining.protein * 0.25, 5)

  if (lang === "ar") {
    if (closeCalories && closeProtein) {
      return `يطابق المتبقّي تقريبًا — ${meal.calories} سعرة و${meal.protein} جم بروتين`
    }
    if (meal.calories <= remaining.calories && closeProtein) {
      return `يغطّي ${meal.protein} جم من بروتينك المتبقّي (${remaining.protein} جم)، ويتبقّى ${kcalLeft} سعرة`
    }
    if (closeProtein) {
      return `يحقّق هدف البروتين بـ ${meal.protein} جم، ويزيد قليلًا عن سعراتك المتبقّية (${remaining.calories} سعرة)`
    }
    if (meal.calories <= remaining.calories) {
      return `${meal.calories} سعرة و${meal.protein} جم بروتين — أقل بمريح من سعراتك المتبقّية (${remaining.calories} سعرة)`
    }
    return `${meal.calories} سعرة و${meal.protein} جم بروتين، قريب من المتبقّي لديك (${remaining.calories} سعرة / ${remaining.protein} جم بروتين)`
  }

  if (closeCalories && closeProtein) {
    return `Matches what's left almost exactly — ${meal.calories} kcal, ${meal.protein} g protein`
  }
  if (meal.calories <= remaining.calories && closeProtein) {
    return `Covers ${meal.protein} g of your ${remaining.protein} g protein left, with ${kcalLeft} kcal to spare`
  }
  if (closeProtein) {
    return `Hits your protein target with ${meal.protein} g, just over your remaining ${remaining.calories} kcal`
  }
  if (meal.calories <= remaining.calories) {
    return `${meal.calories} kcal and ${meal.protein} g protein — comfortably under your ${remaining.calories} kcal left`
  }
  return `${meal.calories} kcal and ${meal.protein} g protein, close to your ${remaining.calories} kcal / ${remaining.protein} g protein left`
}

const buildSuggestions = (shortlist, remaining, lang = "en") =>
  shortlist.slice(0, SUGGEST_COUNT).map((meal) => ({
    meal,
    reason: describeFit(meal, remaining, lang),
  }))

export const suggestMeals = async (userId, remaining, lang = "en") => {
  // 1. Nothing meaningful left to fill.
  if (remaining.calories < SUGGEST_MIN_CALORIES) {
    return { suggestions: [], targetReached: true, aiUsed: false }
  }

  // 2. Cheap DB-side pre-filter: never consider a meal well past the calories
  //    left. Order calories desc, cap the pull. `calories` is an integer
  //    column — round the filter value, since float arithmetic upstream
  //    (target - consumed) * 1.3 can produce something like 1445.6000000001,
  //    which Postgres rejects outright as an integer literal.
  const { data: rows, error } = await supabase
    .from("catalog_meals")
    .select(SELECT_WITH_CATEGORY)
    .lte("calories", Math.round(remaining.calories * 1.3))
    .order("calories", { ascending: false })
    .limit(CANDIDATE_LIMIT)

  if (error) throw ApiError.badRequest("Failed to load meals", error.message)

  if (!rows || rows.length === 0) {
    return { suggestions: [], targetReached: false, aiUsed: false }
  }

  // 3. Deterministic shortlist via the pure scoring util, described with
  //    numbers-driven reasons — no Gemini call on this path (see describeFit).
  const candidates = rows.map(rowToCatalogMeal)
  const shortlist = rankMealsForRemaining(candidates, remaining, { max: SHORTLIST_MAX })

  return {
    suggestions: buildSuggestions(shortlist, remaining, lang),
    targetReached: false,
    aiUsed: false,
  }
}
