-- Fuel — spoken-name aliases on catalog meals, for voice meal logging.
-- Voice logging transcribes Egyptian Arabic (or English) speech on-device and
-- asks Gemini to match each spoken item against the catalog. Catalog names are
-- English, so aliases are the bridge: "بيض مسلوق" → "Boiled Eggs",
-- "عيش توست" → "Toast". Every confirmed voice log teaches the phrase the user
-- actually said back to the meal it matched.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- The whole file is idempotent (safe to run twice). Backend code tolerates this
-- migration NOT having run: selects/inserts retry without the aliases column.

-- ---------------------------------------------------------------------------
-- catalog_meals.aliases — alternative spoken names, never null (empty array
-- means "no aliases learned yet"). No RLS change needed: aliases live on
-- catalog_meals, which already has its own read/write policies from 0002/0004.
-- ---------------------------------------------------------------------------
alter table public.catalog_meals
  add column if not exists aliases text[] not null default '{}';

-- GIN index so alias containment/overlap lookups stay cheap as the catalog grows.
create index if not exists catalog_meals_aliases_idx
  on public.catalog_meals using gin (aliases);
