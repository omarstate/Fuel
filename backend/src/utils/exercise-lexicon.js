// Egyptian gym lexicon for VOICE SET LOGGING. Static data, no DB access.
//
// It does double duty:
//  1. `glossaryLines()` feeds the Gemini parse prompt so the model knows what
//     "تفتيح", "مرجحة" or "مكبس رجل" actually are.
//  2. `canonicalExerciseName()` gives the DETERMINISTIC matcher a way to turn
//     Egyptian speech into the canonical English name the catalog uses, so
//     "بنش برس" can match a row named "Bench Press" with no aliases stored yet.
//
// Coverage is "what an Egyptian commercial gym actually has", not an exhaustive
// exercise database. Anything missing simply falls through to the AI matcher.

// Normalizer kept private and deliberately duplicated from
// match-workout-name.js (same house rule as compute-targets / normalizeMealText):
// importing it the other way round would make the two modules circular.
const normalize = (value) =>
  String(value ?? "")
    .toLowerCase()
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/[ىئ]/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()

/**
 * Canonical English exercise name -> the Egyptian/colloquial ways people say it.
 * @type {{ en: string, ar: string[] }[]}
 */
export const EXERCISE_LEXICON = [
  // --- Presses / chest ---
  { en: "Bench Press", ar: ["بنش", "بنش برس", "بنش بريس", "بنش مستوي", "بنش فلات", "ضغط بنش"] },
  { en: "Incline Bench Press", ar: ["بنش مايل", "بنش علوي", "انكلاين", "بنش عالي"] },
  { en: "Decline Bench Press", ar: ["بنش مقلوب", "بنش سفلي", "ديكلاين"] },
  { en: "Dumbbell Bench Press", ar: ["بنش دمبل", "بنش بالدمبل", "ضغط دمبل"] },
  { en: "Incline Dumbbell Press", ar: ["بنش مايل دمبل", "دمبل مايل"] },
  { en: "Smith Machine Bench Press", ar: ["بنش سميث", "سميث بنش"] },
  { en: "Chest Press Machine", ar: ["جهاز الصدر", "ماكينة صدر", "تشست برس"] },
  { en: "Push-up", ar: ["ضغط", "تمرين ضغط", "بوش اب", "الضغط"] },

  // --- Chest flyes ---
  { en: "Chest Fly", ar: ["تفتيح", "تفتيح دمبل", "فلاي"] },
  { en: "Incline Chest Fly", ar: ["تفتيح مايل"] },
  { en: "Pec Deck", ar: ["بترفلاي", "جهاز التفتيح", "بك ديك"] },
  { en: "Cable Crossover", ar: ["كروس اوفر", "تفتيح كابل"] },
  { en: "Pullover", ar: ["بولوفر"] },

  // --- Shoulders ---
  { en: "Overhead Press", ar: ["كتف", "برس كتف", "ضغط كتف", "بريس كتف", "كتف بار"] },
  { en: "Dumbbell Shoulder Press", ar: ["كتف دمبل", "ضغط كتف دمبل", "برس كتف بالدمبل"] },
  { en: "Machine Shoulder Press", ar: ["جهاز كتف", "ماكينة كتف"] },
  { en: "Arnold Press", ar: ["ارنولد", "ارنولد برس"] },
  { en: "Lateral Raise", ar: ["رفرفة جانبي", "رفرفة جانبية", "رفرفه جانبي", "ليترال"] },
  { en: "Front Raise", ar: ["رفرفة امامي", "رفرفة امامية", "فرونت رايز"] },
  { en: "Rear Delt Fly", ar: ["رفرفة خلفي", "رفرفة خلفية", "ريردلت", "دلت خلفي"] },
  { en: "Shrug", ar: ["هز كتف", "هز اكتاف", "شراج", "ترابيس"] },
  { en: "Upright Row", ar: ["سحب للذقن", "ابرايت رو"] },
  { en: "Face Pull", ar: ["فيس بول", "سحب للوش"] },

  // --- Rows / pulls ---
  { en: "Barbell Row", ar: ["تجديف", "سحب بار", "رو", "تجديف بار", "باربل رو"] },
  { en: "Dumbbell Row", ar: ["تجديف دمبل", "رو دمبل", "سحب دمبل"] },
  { en: "Seated Cable Row", ar: ["تجديف كابل", "سحب ارضي", "رو كابل", "تجديف قاعد"] },
  { en: "Machine Row", ar: ["جهاز تجديف", "ماكينة تجديف"] },
  { en: "T-Bar Row", ar: ["تي بار", "تجديف تي بار"] },
  { en: "Lat Pulldown", ar: ["سحب امامي", "بولي امامي", "لات بولداون", "سحب عالي"] },
  { en: "Straight Arm Pulldown", ar: ["سحب ذراع مفرود", "بولوفر كابل"] },
  { en: "Pull-up", ar: ["عقلة", "عقل", "بار عقلة", "بول اب"] },
  { en: "Chin-up", ar: ["عقلة عكسي", "عقلة قبضة ضيقة", "تشن اب"] },

  // --- Squats & legs ---
  { en: "Back Squat", ar: ["سكوات", "اسكوات", "سكوات خلفي", "سكوات بار"] },
  { en: "Front Squat", ar: ["سكوات امامي", "فرونت سكوات"] },
  { en: "Goblet Squat", ar: ["سكوات دمبل", "جوبليت"] },
  { en: "Smith Machine Squat", ar: ["سكوات سميث", "سميث سكوات"] },
  { en: "Hack Squat", ar: ["هاك سكوات", "جهاز سكوات"] },
  { en: "Leg Press", ar: ["مكبس رجل", "مكبس", "ليج برس", "جهاز الرجل"] },
  { en: "Leg Extension", ar: ["دوران امامي", "ليج اكستنشن", "بسط الرجلين", "تمديد رجل"] },
  { en: "Leg Curl", ar: ["دوران خلفي", "ليج كيرل", "ثني الرجلين", "خلفي رجل"] },
  { en: "Lunge", ar: ["طعنات", "طعنة", "لانجز"] },
  { en: "Bulgarian Split Squat", ar: ["سكوات بلغاري", "بلغاري"] },
  { en: "Step-up", ar: ["صعود درج", "ستيب اب"] },
  { en: "Calf Raise", ar: ["سمانة", "رفع سمانة", "كالف"] },
  { en: "Seated Calf Raise", ar: ["سمانة قاعد"] },
  { en: "Standing Calf Raise", ar: ["سمانة واقف"] },
  { en: "Hip Thrust", ar: ["هيب ثراست", "رفع حوض"] },
  { en: "Glute Bridge", ar: ["جسر", "بريدج"] },

  // --- Hinges / deadlifts ---
  { en: "Deadlift", ar: ["ديدليفت", "ديد ليفت", "الرفعة الميتة", "رفعة ميتة"] },
  { en: "Romanian Deadlift", ar: ["رومانيان", "ديدليفت روماني", "رفعة رومانية", "ار دي ال"] },
  { en: "Sumo Deadlift", ar: ["ديدليفت سومو", "سومو"] },
  { en: "Rack Pull", ar: ["راك بول"] },
  { en: "Good Morning", ar: ["جود مورنينج"] },

  // --- Arms ---
  { en: "Biceps Curl", ar: ["باي", "بايسبس", "مرجحة", "مرجحة بار", "ثني باي"] },
  { en: "Dumbbell Curl", ar: ["مرجحة دمبل", "باي دمبل"] },
  { en: "Hammer Curl", ar: ["هامر", "هامر كيرل", "مرجحة هامر"] },
  { en: "Preacher Curl", ar: ["باي سكوت", "بريتشر", "مرجحة سكوت"] },
  { en: "Cable Curl", ar: ["باي كابل", "مرجحة كابل"] },
  { en: "Reverse Curl", ar: ["مرجحة عكسي", "ريفيرس كيرل"] },
  { en: "Wrist Curl", ar: ["ساعد", "مرجحة ساعد"] },
  { en: "Triceps Pushdown", ar: ["تراي كابل", "تراي", "بوش داون", "ضغط تراي"] },
  { en: "Skullcrusher", ar: ["سكل كراشر", "فرنساوي", "تراي مستلقي"] },
  { en: "Overhead Triceps Extension", ar: ["تراي خلف الراس", "تمديد تراي"] },
  { en: "Close-Grip Bench Press", ar: ["بنش ضيق", "بنش قبضة ضيقة"] },
  { en: "Dip", ar: ["متوازي", "ديبس", "ديب"] },

  // --- Core ---
  { en: "Plank", ar: ["بلانك", "بلانك بطن"] },
  { en: "Side Plank", ar: ["بلانك جانبي"] },
  { en: "Crunch", ar: ["كرانش", "بطن", "تمرين بطن"] },
  { en: "Cable Crunch", ar: ["كرانش كابل", "بطن كابل"] },
  { en: "Sit-up", ar: ["سيت اب", "بطن كامل"] },
  { en: "Hanging Leg Raise", ar: ["رفع رجلين", "رفع الرجلين معلق", "بطن معلق"] },
  { en: "Russian Twist", ar: ["تويست روسي", "رشن تويست"] },
  { en: "Ab Wheel", ar: ["عجلة البطن", "اب ويل"] },

  // --- Conditioning / carries ---
  { en: "Treadmill", ar: ["مشاية", "تريدميل", "جري"] },
  { en: "Stationary Bike", ar: ["عجلة", "بايك ثابت"] },
  { en: "Kettlebell Swing", ar: ["كيتل بيل", "سوينج"] },
  { en: "Farmer's Walk", ar: ["مشي الفلاح", "فارمرز"] },
]

/**
 * Words that qualify a base movement rather than naming one. Used two ways: the
 * prompt lists them, and `canonicalExerciseName` peels them off a spoken phrase
 * to find the base exercise, then tries to re-compose a dedicated variant
 * ("بنش" + "مايل" → "Incline Bench Press").
 * @type {{ en: string, ar: string[] }[]}
 */
export const MODIFIER_LEXICON = [
  { en: "incline", ar: ["مايل", "علوي"] },
  { en: "decline", ar: ["مقلوب", "سفلي"] },
  { en: "standing", ar: ["واقف", "وقوف"] },
  { en: "seated", ar: ["قاعد", "جالس"] },
  { en: "wide grip", ar: ["واسع", "قبضة واسعة"] },
  { en: "close grip", ar: ["ضيق", "قبضة ضيقة"] },
  { en: "dumbbell", ar: ["دمبل", "بدمبل", "بالدمبل"] },
  { en: "barbell", ar: ["بار", "بالبار"] },
  { en: "cable", ar: ["كابل", "بالكابل"] },
  { en: "machine", ar: ["ماكينة", "جهاز"] },
  { en: "smith machine", ar: ["سميث"] },
]

/**
 * Movements that carry no external load by default. The prompt uses these to
 * decide `bodyweight: true` and to read a lone number as REPS rather than kilos.
 * @type {string[]}
 */
export const BODYWEIGHT_TERMS = [
  "عقلة",
  "عقل",
  "ضغط",
  "بلانك",
  "متوازي",
  "ديبس",
  "بطن",
  "كرانش",
  "pull-up",
  "chin-up",
  "push-up",
  "plank",
  "dip",
  "crunch",
  "sit-up",
  "hanging leg raise",
]

// ---------------------------------------------------------------------------
// Lookup indexes (built once at module load)
// ---------------------------------------------------------------------------

// normalized spoken phrase -> canonical English name. Both the English name and
// every Arabic alias are keys, so English speech resolves too.
const INDEX = new Map()
for (const entry of EXERCISE_LEXICON) {
  for (const phrase of [entry.en, ...entry.ar]) {
    const key = normalize(phrase)
    if (key && !INDEX.has(key)) INDEX.set(key, entry.en)
  }
}

// Single normalized token -> canonical English modifier. Multi-word Arabic
// modifiers ("قبضة ضيقة") are skipped here; they still reach the model through
// the prompt glossary.
const MODIFIER_INDEX = new Map()
for (const entry of MODIFIER_LEXICON) {
  for (const phrase of [entry.en, ...entry.ar]) {
    const key = normalize(phrase)
    if (key && !key.includes(" ") && !MODIFIER_INDEX.has(key)) MODIFIER_INDEX.set(key, entry.en)
  }
}

// Longest indexed phrase that appears as a whole-token run inside `phrase`.
// Longest wins so "بنش مايل دمبل" prefers its own entry over bare "بنش".
const lookupPhrase = (phrase) => {
  if (!phrase) return null
  const direct = INDEX.get(phrase)
  if (direct) return direct

  const padded = ` ${phrase} `
  let best = null
  let bestLength = 0
  for (const [key, en] of INDEX) {
    if (key.length <= bestLength) continue
    if (padded.includes(` ${key} `)) {
      best = en
      bestLength = key.length
    }
  }
  return best
}

/**
 * Resolve a spoken exercise phrase to its canonical ENGLISH name, or null when
 * the lexicon doesn't know it. Conservative on purpose — a wrong canonical name
 * would make the deterministic matcher pick the wrong catalog row.
 *
 * @param {string} spoken  e.g. "بنش برس", "بنش مايل", "lat pulldown"
 * @returns {string | null} e.g. "Bench Press", "Incline Bench Press"
 */
export const canonicalExerciseName = (spoken) => {
  const text = normalize(spoken)
  if (!text) return null

  const direct = INDEX.get(text)
  if (direct) return direct

  // Peel modifier words off, resolve what's left, then try to re-compose a
  // dedicated variant entry from the modifiers we removed.
  const modifiers = []
  const rest = []
  for (const token of text.split(" ")) {
    if (!token) continue
    const modifier = MODIFIER_INDEX.get(token)
    if (modifier) modifiers.push(modifier)
    else rest.push(token)
  }

  const base = lookupPhrase(rest.join(" ")) ?? lookupPhrase(text)
  if (!base) return null

  for (const modifier of modifiers) {
    const composed = INDEX.get(normalize(`${modifier} ${base}`))
    if (composed) return composed
  }

  return base
}

// How many aliases per line make it into the prompt glossary. Enough to teach
// the model the shape of the phrase without bloating the prompt.
const ALIASES_PER_GLOSSARY_LINE = 4

/**
 * Compact `عربي، عربي = English` lines for the parse prompt.
 * @returns {string}
 */
export const glossaryLines = () =>
  EXERCISE_LEXICON.map((entry) => `${entry.ar.slice(0, ALIASES_PER_GLOSSARY_LINE).join("، ")} = ${entry.en}`).join(
    "\n"
  )

/**
 * Compact `عربي = english modifier` lines for the parse prompt.
 * @returns {string}
 */
export const modifierLines = () =>
  MODIFIER_LEXICON.map((entry) => `${entry.ar.join("، ")} = ${entry.en}`).join("\n")
