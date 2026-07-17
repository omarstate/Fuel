import { env } from "../config/env.js"
import { ApiError } from "../utils/api-error.js"

// Low-level Gemini (Google Generative Language) client. No DB access — it only
// knows how to send a prompt and hand back parsed JSON + grounding sources.
// The API key never leaves this module and is never logged or thrown.

const ENDPOINT = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`

const TIMEOUT_MS = 60_000

// Retry on these primary-model failures with the fallback model.
const RETRYABLE_STATUSES = new Set([429, 404, 500, 502, 503, 504])

// Strip ```json … ``` or ``` … ``` fences that Gemini often wraps JSON in.
const stripFences = (text) => {
  const trimmed = text.trim()
  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i)
  return (fenced ? fenced[1] : trimmed).trim()
}

// Best-effort JSON parse: try as-is, then slice from the first {/[ to the last
// }/] and try again. Throws a clean ApiError if both fail.
const parseJsonLoose = (raw) => {
  const cleaned = stripFences(raw)
  try {
    return JSON.parse(cleaned)
  } catch {
    // fall through to a bracket slice
  }

  const firstObj = cleaned.indexOf("{")
  const firstArr = cleaned.indexOf("[")
  const starts = [firstObj, firstArr].filter((i) => i >= 0)
  if (starts.length === 0) throw ApiError.badRequest("AI returned an unreadable answer")

  const start = Math.min(...starts)
  const openChar = cleaned[start]
  const closeChar = openChar === "{" ? "}" : "]"
  const end = cleaned.lastIndexOf(closeChar)
  if (end <= start) throw ApiError.badRequest("AI returned an unreadable answer")

  try {
    return JSON.parse(cleaned.slice(start, end + 1))
  } catch {
    throw ApiError.badRequest("AI returned an unreadable answer")
  }
}

const extractText = (payload) => {
  const parts = payload?.candidates?.[0]?.content?.parts ?? []
  return parts
    .map((part) => part?.text ?? "")
    .join("")
    .trim()
}

const extractSources = (payload) => {
  const chunks = payload?.candidates?.[0]?.groundingMetadata?.groundingChunks ?? []
  return chunks
    .map((chunk) => chunk?.web)
    .filter((web) => web && web.uri)
    .map((web) => ({ uri: web.uri, title: web.title ?? null }))
}

// Single HTTP call to one model. Returns { ok, status, payload } — networking
// errors are normalized to a synthetic 599 so the caller can decide to retry.
const callModel = async (model, body) => {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    const res = await fetch(ENDPOINT(model), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": env.GEMINI_API_KEY,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    })

    let payload = null
    try {
      payload = await res.json()
    } catch {
      payload = null
    }

    return { ok: res.ok, status: res.status, payload }
  } catch {
    // Timeout or network failure — treat as retryable.
    return { ok: false, status: 599, payload: null }
  } finally {
    clearTimeout(timer)
  }
}

/**
 * generateJson — send a prompt to Gemini and parse the JSON reply.
 * @returns {Promise<{ data: unknown, sources: {uri:string,title:string|null}[], modelUsed: string }>}
 */
export const generateJson = async ({ prompt, useSearch = false, temperature = 0.2 }) => {
  const body = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: { temperature },
  }
  if (useSearch) body.tools = [{ google_search: {} }]

  const primary = env.GEMINI_MODEL
  const fallback = env.GEMINI_FALLBACK_MODEL

  let result = await callModel(primary, body)
  let modelUsed = primary

  if (!result.ok && RETRYABLE_STATUSES.has(result.status) && fallback && fallback !== primary) {
    result = await callModel(fallback, body)
    modelUsed = fallback
  }

  if (!result.ok) {
    throw ApiError.badRequest("AI lookup failed", `Gemini request failed (status ${result.status})`)
  }

  const text = extractText(result.payload)
  if (!text) throw ApiError.badRequest("AI returned an empty answer")

  const data = parseJsonLoose(text)
  const sources = extractSources(result.payload)

  return { data, sources, modelUsed }
}
