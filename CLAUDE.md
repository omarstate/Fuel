# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Frontend (`frontend/`):
- `npm run dev` — Vite dev server (`--host`, auto-picks a port if 5173 is busy)
- `npx tsc -b` (or `npm run typecheck`) — typecheck (run this after any TS change; there are no tests)
- `npm run build` — `tsc -b && vite build`
- `npm run lint` / `npm run format`

Backend (`backend/`):
- `npm run dev` — `node --env-file=.env --watch server.js` (hot-reloads on save; port 4000)
- `node --check <file>` — syntax-check individual ESM files
- Health check: `curl localhost:4000/api/health`

There is no test suite. Verification is: `tsc -b` + `vite build` for the frontend, `node --check` +
booting the dev server and curling routes for the backend.

Database migrations (`supabase/migrations/*.sql`) are **never applied automatically**. The user pastes
them into the Supabase Dashboard SQL editor manually. Write new migrations as numbered files following
the existing header-comment style, make them idempotent, and make code tolerate the migration not having
run yet.

## Repository layout

The product lives in `frontend/` + `backend/` + `supabase/` (deployed via `render.yaml` to Render).
`mainframe/`, `prisma/`, and `vanguard/` are separate throwaway Vite experiments — leave them alone.

Multiple Claude sessions sometimes edit this repo concurrently. Check `git status` before assuming
uncommitted changes are yours; don't revert work you didn't write.

## Architecture

### Two frontend surfaces
- `frontend/src/app-editorial/` — **the real app** (light "editorial" theme, `/dashboard/*` routes,
  auth-gated via `RequireAuth`). The landing page at `/` is `pages/landing-editorial.tsx`.
- `frontend/src/app/` — legacy dark surface at `/app/*`; still compiled, rarely touched. Shared types
  like `MealType`/`mealTypeLabel`/`suggestedMealType` live in `src/app/nutrition/types.ts` and are
  imported by the editorial app.

Theming: the editorial tree opts into `.theme-fuel-light` (class set on `<html>` by the app shell so
portaled dialogs/toasts inherit it). CSS variables in `src/index.css`.

### Split data flow (important)
- **Shared catalog, profile, AI, workouts catalog** → Express API via `src/lib/api.ts` (typed fetch
  wrapper that attaches the Supabase access token as a Bearer header; `request()` unwraps the
  `{ data }` envelope, `requestBody()` returns the whole body for paginated `count`).
- **Personal logs** (meals log, workout sessions) → written **directly with supabase-js** under RLS
  from hooks like `app-editorial/use-meals.ts` and `workouts/session/use-active-session.ts`. Don't
  route these through the backend.

### Backend layering (`backend/src/`)
`routes/*` → `controllers/*` (zod `.parse` + `assertSupabaseConfigured`/`assertGeminiConfigured`) →
`services/*` (supabase **service-role** client) → `models/*` (snake_case row ↔ camelCase DTO mappers).
Central `middleware/error-handler.js` maps `ZodError`→400 and `ApiError`→its status; controllers just
throw. Auth = `middleware/require-auth.js` verifying the Bearer token against Supabase; admin status
comes from the `ADMIN_EMAILS` env allowlist (`utils/is-admin.js`).

### AI features (Gemini, backend-only)
The `GEMINI_API_KEY` lives only in `backend/.env`; it must never reach the frontend or logs.
- `services/gemini.client.js` — REST calls to `generativelanguage.googleapis.com`; tries
  `GEMINI_MODEL` then falls back to `GEMINI_FALLBACK_MODEL` on 429/404/5xx (free-tier keys 429 on the
  newest models); strips ```json fences before parsing; exposes grounding sources.
- **Meal lookup** (`POST /api/ai/meals/lookup`): checks `catalog_meals` for matches first (never
  duplicates), then a search-grounded Gemini call; persists results with `ai_source`
  ('official'|'estimate'), `source_url`, and `macro_ranges` (jsonb min/max, shown as ranges in the UI).
- **Coach insights** (`GET /api/ai/insights`): deterministic facts (streaks via
  `utils/compute-streak.js`, 14-day aggregates) + Gemini narrative, **cached one row per user per UTC
  day** in `ai_insights`.
- **Meal estimate** (`POST /api/meals/estimate`, via `services/ai-nutrition.service.js`): batch
  free-text estimation for the quick-log flow (`ai-estimate-dialog.tsx`) — one grounded Gemini call
  per comma-separated item, with an **Egypt-first** prompt (local menus/portions before regional or
  global data). Returns estimates for a review step; does **not** write to the catalog, unlike lookup.
- **Meal suggestions** (`POST /api/ai/meals/suggest`): deliberately **no Gemini call** — purely the
  weighted scoring in `utils/score-meals.js` (protein 3×, calories 2×, carbs/fat 1×, hard penalty
  >115% of remaining kcal) with reasons generated from the numbers. It fires on nearly every meal
  log, which made per-call AI impractical on a free-tier quota. Keep it deterministic.

### Barcode lookup (Open Food Facts, three surfaces)
OFF rate-limits per IP and Render's free tier shares egress IPs, so the deployed backend gets
chronic 429s that a user's own device never sees. The design assumes that:
- Backend `GET /api/meals/barcode/:code` (`services/barcode.service.js`) is cache-first — a
  Supabase `barcode_products` table (migration 0012, fail-soft if not applied). Only 'off'-sourced
  rows short-circuit; 'client'-sourced rows are unverified hints that never block a live OFF fetch
  and are deleted when OFF denies the barcode.
- On any 5xx/network failure, **both clients call OFF directly from the device** and best-effort
  `POST /api/meals/barcode/:code` the result into the shared cache ('client' source, zod-bounded,
  can never overwrite an 'off' row). 4xx errors surface to the user, never trigger the fallback.
- The OFF normalization exists **three times on purpose**: `backend/src/services/barcode.service.js`,
  `frontend/src/lib/openfoodfacts.ts`, `ios/Fuel/Core/Networking/OpenFoodFacts.swift`. If you change
  one, change all three (string-number parsing is deliberately POSIX/`Number()`-strict everywhere).

### Nutrition targets (BMR)
Mifflin-St Jeor math exists twice **on purpose**: `backend/src/utils/compute-targets.js`
(authoritative, persists to `profiles`) and `frontend/src/lib/nutrition.ts` (mirror for live form
previews). If you change one, change both. Per-user targets flow through `MeProvider`/`useTargets()`
(`app-editorial/use-me.tsx`) with `DEFAULT_TARGETS` as the no-profile fallback; onboarding is a
non-dismissible dialog shown when `needsOnboarding` (signed in, no profile row).

### UI conventions
- Style: 2-space indent, double quotes, **no semicolons** in TS/TSX; match neighbouring files.
- Async DB actions use the morph-button system: `components/ui/badge-morph.tsx` (presentational
  status pill) + `components/ui/morph-button.tsx` (idle→loading→success/error lifecycle;
  `intent="destructive"` renders red success) + `app-editorial/add-to-log-button.tsx` (section-picking
  dropdown + morph). Inline row deletes are non-optimistic and split into `deleteX()` (DB) +
  `dropX()` (local state) so the pill can show "Deleted" before the row animates out.
- Library lists are paginated server-side (`GET /api/meals` supports `category`/`search`/`limit`/
  `offset` + `count`) with a 5-min module-level cache in `library/use-paged-meals.ts`; call
  `invalidateMealsCache()` after any catalog mutation.
- Meals log entries carry a `meal_type` section (breakfast/lunch/dinner/snack) — quick-add flows must
  pass one (default `suggestedMealType()`), never hardcode it.

### Environment
- `backend/.env` (gitignored): `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_EMAILS`,
  `CORS_ORIGIN`, `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_FALLBACK_MODEL`, `PORT`.
- `frontend/.env.local`: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_API_URL`.
- Missing config degrades to 503s via `assert*Configured()` rather than crashing — preserve that.
