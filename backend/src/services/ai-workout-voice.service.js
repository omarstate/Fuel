// Voice SET logging — parse a spoken transcript into structured sets.
//
// Mid-workout the user talks to the phone ("بنش برس تمانين في تمانية",
// "bench press 80 for 8, then 85 for 6"). The app transcribes on-device and
// posts the text here. ONE ungrounded Gemini call does everything: it splits
// the utterance into exercises, turns spoken Egyptian numbers into weights and
// reps, and matches each exercise against BOTH the workout catalog (names +
// the `aliases` column that bridges Arabic speech to English catalog names) and
// the exercises already in the user's live session.
//
// This service NEVER writes session rows: the app inserts those straight into
// Supabase under RLS. `commitVoiceSetLog` persists catalog changes only — and
// it has to, because `workouts` is public-read with no insert/update policies,
// so only the service-role client here can touch it.

import { supabase } from "../config/supabase.js"
import { rowToWorkout } from "../models/workout.model.js"
import { generateJson } from "./gemini.client.js"
import { ApiError } from "../utils/api-error.js"
import { matchWorkoutName } from "../utils/match-workout-name.js"
import { glossaryLines, modifierLines, BODYWEIGHT_TERMS } from "../utils/exercise-lexicon.js"
import {
  voiceSetParseSchema,
  voiceParsedExerciseSchema,
  expandSetGroups,
  MAX_VOICE_EXERCISES,
  MAX_SETS_PER_EXERCISE,
  MAX_TOTAL_SETS,
} from "../validators/ai-workout-voice.validator.js"

const SELECT_WITH_CATEGORIES = "*, workout_categories(id, name, slug)"

// How much of the catalog we show the model. Names + aliases + muscle/equipment
// only, so 500 rows stay well inside a sane prompt budget.
const CANDIDATE_LIMIT = 500
const CANDIDATE_COLUMNS_WITH_ALIASES = "id, name, aliases, primary_muscle, equipment"
const CANDIDATE_COLUMNS = "id, name, primary_muscle, equipment"

// Aliases kept per catalog workout (oldest first, newest dropped past the cap).
const MAX_ALIASES_PER_WORKOUT = 12
// Aliases per row we bother showing the model.
const ALIASES_IN_PROMPT = 6

// -------------------------------------------------------------------------
// `aliases` column tolerance
// -------------------------------------------------------------------------

// 0011_workout_aliases.sql is applied by hand, so every read/write that mentions
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
    .from("workouts")
    .select(CANDIDATE_COLUMNS_WITH_ALIASES)
    .limit(CANDIDATE_LIMIT)

  if (!withAliases.error) {
    return (withAliases.data ?? []).map((row) => ({ ...row, aliases: asAliasArray(row.aliases) }))
  }

  if (!isMissingAliasesColumn(withAliases.error)) {
    throw ApiError.badRequest("Failed to load workouts", withAliases.error.message)
  }

  // Migration hasn't run — match on names alone (plus the built-in lexicon).
  const plain = await supabase.from("workouts").select(CANDIDATE_COLUMNS).limit(CANDIDATE_LIMIT)
  if (plain.error) throw ApiError.badRequest("Failed to load workouts", plain.error.message)
  return (plain.data ?? []).map((row) => ({ ...row, aliases: [] }))
}

// One JSON object per line, and only the fields the matcher needs — empty
// aliases and null columns are omitted to keep the prompt small.
const catalogLine = (row) => {
  const entry = { id: row.id, name: row.name }
  const aliases = row.aliases.slice(0, ALIASES_IN_PROMPT)
  if (aliases.length > 0) entry.aliases = aliases
  if (row.primary_muscle) entry.primaryMuscle = row.primary_muscle
  if (row.equipment) entry.equipment = row.equipment
  return JSON.stringify(entry)
}

// The live session, same compact one-object-per-line shape. `lastWeight` /
// `lastReps` are what make "نفس الوزن" ("same weight") resolvable.
const sessionLine = (entry) => {
  const line = { id: entry.id, name: entry.name, setCount: entry.setCount ?? 0 }
  if (entry.lastWeight != null) line.lastWeight = entry.lastWeight
  if (entry.lastReps != null) line.lastReps = entry.lastReps
  return JSON.stringify(line)
}

// -------------------------------------------------------------------------
// Step 2 — the parse + match prompt
// -------------------------------------------------------------------------

const PARSE_PROMPT = ({ transcript, unit, catalogLines, catalogCount, sessionLines, sessionCount }) =>
  `You are the parser behind VOICE SET LOGGING in a gym app. The user is MID-WORKOUT, phone in hand, and just said this out loud. It was transcribed on-device in a loud gym, so it may be imperfect — read through small mis-hearings instead of taking them literally:
"""
${transcript}
"""

The users are in EGYPT. They speak colloquial EGYPTIAN ARABIC, English, or both mixed inside one sentence ("bench press تمانين في تمانية"). The user's app is set to ${unit.toUpperCase()}, so a bare number that is clearly a weight is in ${unit} unless they say another unit out loud.

NUMBERS AS WORDS — Egyptian speech, not digits:
- Units: واحد/واحدة = 1, اتنين = 2, تلاتة/تلات = 3, اربعة/اربع = 4, خمسة/خمس = 5, ستة/ست = 6, سبعة/سبع = 7, تمانية/تمان = 8, تسعة/تسع = 9, عشرة/عشر = 10.
- Teens: حداشر = 11, اتناشر = 12, تلاتاشر = 13, اربعتاشر = 14, خمستاشر = 15, ستاشر = 16, سبعتاشر = 17, تمنتاشر = 18, تسعتاشر = 19.
- Tens: عشرين = 20, تلاتين = 30, اربعين = 40, خمسين = 50, ستين = 60, سبعين = 70, تمانين = 80, تسعين = 90.
- Hundreds: مية = 100, ميتين = 200, تلتمية = 300. Compounds read as spoken: "مية وخمسة وعشرين" = 125, "مية وعشرة" = 110.
- نص = .5 and ربع = .25, but ONLY on a weight ("سبعين ونص" = 70.5). Reps are always whole numbers.
- Arabic-Indic digits (٨٠) mean exactly the same as Western ones (80).

VOCABULARY — Egyptian gym names (spoken = the exercise they mean):
${glossaryLines()}

MODIFIERS that qualify a movement rather than name one:
${modifierLines()}

OTHER WORDS:
- Sets: مجموعة / مجموعات / سِت / ستات / طقم / set / sets.
- Reps: عدة / عدات / تكرار / rep / reps / times.
- "في" / "×" / "by" / "for" / "على" sitting BETWEEN two numbers is the multiplier word. It is NEVER the word "kilograms".
- Units: كيلو / كجم / kg / kilos = kilograms; رطل / باوند / pound / lb = pounds — when pounds are spoken, report the number as spoken with "unit": "lb" and do NOT convert it yourself.
- "بار فاضي" / "empty bar" / "البار لوحده" = 20 kg.
- "وزن الجسم" / "بدون وزن" / "bodyweight" = no external weight at all.
- Effort and style words — "للفشل" / "to failure", "دروب سِت" / "drop set", "سوبر سِت" / "superset", "تسخين" / "warm-up", "سهلة", "تقيلة" — belong in that set's "note". They are NEVER a weight and NEVER a rep count.
- Bodyweight movements: ${BODYWEIGHT_TERMS.join("، ")}.

TASK 1 — EXERCISES. Extract every DISTINCT exercise the user mentions, in the order spoken. Never merge two different exercises into one. Never invent an exercise that was not said. Ignore filler ("سجّل", "خلاص", "يلا", "log", "add this", "ok"). "name" is the canonical ENGLISH name; "nameAr" is the Egyptian name for it.

TASK 2 — SET GROUPS. One group is a weight/reps pair plus how many times it was performed ("count"). Worked examples:
- "بنش تمانين في تمانية" → [{"weight":80,"unit":"kg","reps":8,"count":1}]
- "bench press 80 for 8, then 85 for 6" → [{"weight":80,"unit":"kg","reps":8,"count":1},{"weight":85,"unit":"kg","reps":6,"count":1}]
- "سكوات مية كيلو خمس عدات تلات مجموعات" → [{"weight":100,"unit":"kg","reps":5,"count":3}]
- "3 sets of 10 at 60" → [{"weight":60,"unit":"kg","reps":10,"count":3}]
- "عقلة تلات مجموعات عشرة" → [{"weight":null,"unit":null,"reps":10,"count":3}]
- "نفس الوزن كمان مرتين" after a group → raise that group's "count" by 2 instead of adding empty groups.

TASK 3 — WEIGHT vs REPS. Apply these rules IN ORDER; the first one that fits wins:
1. A number spoken WITH a unit word ("تمانين كيلو", "80 kg") is a WEIGHT. A number spoken with a reps word ("تمن عدات", "8 reps") is REPS.
2. "A في B" / "A × B" / "A for B": if A >= 20 it is weight A × reps B. If A <= 12 AND B >= 4 AND no unit was spoken, it is count A × reps B with "weight": null ("تلاتة في عشرة" = 3 sets of 10). Otherwise treat A as the weight and set "confidence":"low".
3. "for N" / "على N" spoken AFTER a weight is ALWAYS reps. "N kilos" is ALWAYS a weight.
4. Two bare numbers with nothing else: if the larger one is >= 20, the larger is the weight and the smaller the reps.
5. A single bare number after a BODYWEIGHT exercise is REPS.
6. A single bare number after a loaded exercise: >= 20 is the weight (reps null), <= 15 is reps (weight null).
7. NEVER invent a number. If you do not know a weight or a rep count, it is null.

TASK 4 — BODYWEIGHT. For عقلة / ضغط / متوازي / بلانك / بطن and their English equivalents, "weight" is null and "bodyweight" is true. If the user adds load ("عقلة بعشرين كيلو"), set "weight": 20 and keep "bodyweight": true. If the user describes plates instead of a total ("عشرين من كل ناحية"), give your best TOTAL including the 20 kg bar and set "confidence":"low".

TASK 5 — MATCH. Two lists follow.
SESSION — the exercises already logged in this workout, one JSON object per line ({"id","name","setCount","lastWeight","lastReps"}). Set "sessionExerciseId" when the user is clearly adding to one of these. "كمان سِت" / "another set" / "نفس الوزن" / "same weight" refer to these; a bare "كمان سِت" with no exercise named means the LAST entry in the list, and "same weight" means that entry's lastWeight.
CATALOG — the app's exercise library, one JSON object per line ({"id","name","aliases","primaryMuscle","equipment"}). Set "workoutId" when the exercise is genuinely the SAME movement. Scan the WHOLE list before deciding — do not give up early. Colloquial Egyptian names count as matches, as does anything in an entry's "aliases". A different movement pattern is NOT a match (incline bench press is not flat "Bench Press", front squat is not "Back Squat"). A grip or stance variation IS a match when the catalog has no dedicated entry for it ("close-grip bench" → "Bench Press"). When genuinely torn, return null.
Only ever use ids that appear in these lists. An exercise can have both a "sessionExerciseId" and a "workoutId", or neither.

SESSION (${sessionCount} entries):
${sessionLines || "(none — this workout has no logged exercises yet)"}

CATALOG (${catalogCount} entries):
${catalogLines}

Respond with ONLY a raw JSON object — no markdown, no code fences, no commentary — using exactly this shape:
{
  "exercises": [
    {
      "spoken": "the words the user used for this exercise, in the original language",
      "name": "canonical ENGLISH name, e.g. Bench Press",
      "nameAr": "Egyptian name, e.g. بنش برس",
      "workoutId": "an id from the CATALOG list above" | null,
      "sessionExerciseId": "an id from the SESSION list above" | null,
      "bodyweight": true | false,
      "confidence": "high" | "medium" | "low",
      "sets": [
        {
          "weight": number | null,
          "unit": "kg" | "lb" | null,
          "reps": integer | null,
          "count": integer >= 1,
          "note": "short note like 'to failure', 'warm-up'" | null
        }
      ]
    }
  ]
}

Return at most ${MAX_VOICE_EXERCISES} exercises and at most ${MAX_SETS_PER_EXERCISE} set groups per exercise. "count" is always at least 1. If the transcript mentions no exercise or set at all, return {"exercises": []}.`

// -------------------------------------------------------------------------
// Endpoint A — parse a transcript (writes nothing)
// -------------------------------------------------------------------------

/**
 * @param {{ transcript: string, lang?: "en"|"ar", unit?: "kg"|"lb",
 *   sessionExercises?: object[] }} input
 *   `lang` is accepted (and validated) for symmetry with the meal voice
 *   endpoint, but this parser has nothing language-specific to emit: every
 *   string it returns is either echoed from the transcript or a number.
 * @returns {Promise<{ exercises: object[] }>} exercises in spoken order
 */
export const parseVoiceSetLog = async ({ transcript, unit = "kg", sessionExercises = [] }) => {
  const candidates = await fetchCandidates()
  const candidateIds = new Set(candidates.map((row) => row.id))
  // The session ids come from the REQUEST, not the DB — the app owns those rows
  // and we only ever echo an id it already sent us.
  const sessionIds = new Set(sessionExercises.map((entry) => entry.id))

  const { data } = await generateJson({
    useSearch: false,
    temperature: 0,
    prompt: PARSE_PROMPT({
      transcript,
      unit,
      catalogLines: candidates.map(catalogLine).join("\n"),
      catalogCount: candidates.length,
      sessionLines: sessionExercises.map(sessionLine).join("\n"),
      sessionCount: sessionExercises.length,
    }),
  })

  const parsed = voiceSetParseSchema.parse(data)

  // Drop entries the model malformed rather than failing the whole utterance.
  const exercises = []
  let setsUsed = 0

  for (const raw of parsed.exercises) {
    const result = voiceParsedExerciseSchema.safeParse(raw)
    if (!result.success) continue

    const item = result.data
    const spoken = item.spoken?.trim() || item.name

    // Never trust a model-supplied id: it must be one we actually sent.
    let workoutId = item.workoutId && candidateIds.has(item.workoutId) ? item.workoutId : null
    const sessionExerciseId =
      item.sessionExerciseId && sessionIds.has(item.sessionExerciseId) ? item.sessionExerciseId : null

    // The model is occasionally lazy about matching. Deterministic token
    // containment against names + aliases + the Egyptian lexicon catches what
    // it missed, and never invents a match it isn't sure of.
    if (!workoutId) {
      workoutId = matchWorkoutName([item.name, item.nameAr, spoken], candidates)
    }

    // A session exercise the app already knows carries its own workout link;
    // trust that over anything we matched, so "كمان سِت" lands on the same row.
    if (!workoutId && sessionExerciseId) {
      const sessionEntry = sessionExercises.find((entry) => entry.id === sessionExerciseId)
      if (sessionEntry?.workoutId && candidateIds.has(sessionEntry.workoutId)) {
        workoutId = sessionEntry.workoutId
      }
    }

    // Budget the sets across the WHOLE response, not just per exercise, so a
    // rambling utterance can't produce a hundred rows for the app to insert.
    const remaining = MAX_TOTAL_SETS - setsUsed
    const sets = expandSetGroups(item.sets, {
      maxSets: Math.min(MAX_SETS_PER_EXERCISE, Math.max(remaining, 0)),
      unit,
    })
    setsUsed += sets.length

    exercises.push({
      spoken,
      name: item.name,
      nameAr: item.nameAr ?? null,
      workoutId,
      sessionExerciseId,
      bodyweight: item.bodyweight === true,
      confidence: item.confidence ?? null,
      sets,
    })

    if (exercises.length >= MAX_VOICE_EXERCISES) break
  }

  if (exercises.length === 0) {
    throw ApiError.badRequest("Couldn't find any exercises in that.")
  }

  // Full rows for the matched workouts, so the app gets real Workout DTOs.
  // `select("*")` is column-agnostic, so no aliases fallback is needed here.
  const matchedIds = [...new Set(exercises.map((exercise) => exercise.workoutId).filter(Boolean))]
  const workoutsById = new Map()
  if (matchedIds.length > 0) {
    const { data: rows, error } = await supabase
      .from("workouts")
      .select(SELECT_WITH_CATEGORIES)
      .in("id", matchedIds)

    if (error) throw ApiError.badRequest("Failed to load matched workouts", error.message)
    for (const row of rows ?? []) workoutsById.set(row.id, rowToWorkout(row))
  }

  return {
    exercises: exercises.map((exercise) => {
      const workout = exercise.workoutId ? workoutsById.get(exercise.workoutId) ?? null : null
      // Precedence matters to the app: a session hit appends to a row that
      // already exists, a catalog hit creates one from the library, and
      // everything else is a free-text custom exercise.
      const kind = exercise.sessionExerciseId ? "session" : workout ? "catalog" : "custom"

      return {
        kind,
        spoken: exercise.spoken,
        name: exercise.name,
        nameAr: exercise.nameAr,
        bodyweight: exercise.bodyweight,
        confidence: exercise.confidence,
        sessionExerciseId: exercise.sessionExerciseId,
        workout,
        sets: exercise.sets,
      }
    }),
  }
}

// -------------------------------------------------------------------------
// Endpoint B — commit catalog changes after the user confirms
// -------------------------------------------------------------------------

// `%` and `_` are ILIKE wildcards — an exercise named "100% Raw Deadlift" must
// not match everything. Escaped with a backslash, ILIKE's default escape char.
const escapeLikePattern = (value) => value.replace(/[\\%_]/g, (char) => `\\${char}`)

/**
 * Merge spoken aliases into a workout's existing list: trimmed, case-insensitively
 * unique, never equal to the workout's own name, capped. Pure — no DB access.
 */
export const mergeAliases = (existing, incoming, workoutName) => {
  const nameKey = (workoutName ?? "").trim().toLowerCase()
  const seen = new Set()
  const merged = []

  for (const value of [...asAliasArray(existing), ...asAliasArray(incoming)]) {
    const trimmed = value.trim()
    if (!trimmed) continue
    const key = trimmed.toLowerCase()
    if (key === nameKey || seen.has(key)) continue
    seen.add(key)
    merged.push(trimmed)
    if (merged.length >= MAX_ALIASES_PER_WORKOUT) break
  }

  return merged
}

// Best-effort alias learning for a workout that already exists. Any failure —
// including the column not existing yet — is swallowed: teaching the catalog a
// new phrase must never break set logging.
const applyAliasUpdate = async (update) => {
  try {
    const current = await supabase
      .from("workouts")
      .select("id, name, aliases")
      .eq("id", update.workoutId)
      .maybeSingle()

    if (current.error || !current.data) return false

    const merged = mergeAliases(current.data.aliases, update.aliases, current.data.name)
    if (merged.length === 0) return false

    const { error } = await supabase.from("workouts").update({ aliases: merged }).eq("id", update.workoutId)

    return !error
  } catch {
    return false
  }
}

// New catalog rows are deliberately left UNCATEGORISED: workouts <-> categories
// is a many-to-many map and guessing a category mid-workout would be worse than
// leaving the library page to sort it out later.
const insertNewWorkout = async (userId, input) => {
  const row = {
    name: input.name,
    description: null,
    primary_muscle: input.primaryMuscle ?? null,
    equipment: input.equipment ?? null,
    target_sets: null,
    target_reps: null,
    created_by: userId,
    aliases: mergeAliases([], input.aliases, input.name),
  }

  const first = await supabase.from("workouts").insert(row).select(SELECT_WITH_CATEGORIES).single()
  if (!first.error) return rowToWorkout(first.data)

  if (!isMissingAliasesColumn(first.error)) {
    throw ApiError.badRequest("Failed to save workout", first.error.message)
  }

  // Migration hasn't run — save the exercise without its aliases rather than fail.
  const { aliases, ...withoutAliases } = row
  const retry = await supabase
    .from("workouts")
    .insert(withoutAliases)
    .select(SELECT_WITH_CATEGORIES)
    .single()

  if (retry.error) throw ApiError.badRequest("Failed to save workout", retry.error.message)
  return rowToWorkout(retry.data)
}

/**
 * @param {string} userId
 * @param {{ aliasUpdates: object[], newWorkouts: object[] }} input
 * @returns {Promise<{ workouts: {name: string, workout: object}[], aliasesUpdated: number }>}
 *   `name` echoes the request so the app can map created exercises back to the
 *   review rows it sent, and link its session rows to the new catalog ids.
 */
export const commitVoiceSetLog = async (userId, { aliasUpdates = [], newWorkouts = [] }) => {
  const workouts = []

  for (const input of newWorkouts) {
    // Case-insensitive exact dedup. limit(1) rather than maybeSingle() — catalog
    // names aren't unique and maybeSingle throws on more than one row.
    const { data: dups, error: dupError } = await supabase
      .from("workouts")
      .select(SELECT_WITH_CATEGORIES)
      .ilike("name", escapeLikePattern(input.name))
      .limit(1)

    if (dupError) throw ApiError.badRequest("Failed to check workout", dupError.message)

    if (dups && dups.length > 0) {
      workouts.push({ name: input.name, workout: rowToWorkout(dups[0]) })
      continue
    }

    workouts.push({ name: input.name, workout: await insertNewWorkout(userId, input) })
  }

  const outcomes = await Promise.all(aliasUpdates.map(applyAliasUpdate))
  const aliasesUpdated = outcomes.filter(Boolean).length

  return { workouts, aliasesUpdated }
}
