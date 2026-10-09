-- Fuel — exercise_catalog: a local mirror of the public-domain free-exercise-db
-- dataset (https://github.com/yuhonas/free-exercise-db, ~870 exercises with
-- muscles, equipment, step-by-step instructions and demo photos).
--
-- This is NOT the app's workout catalog. `workouts` stays the curated library a
-- user actually trains from; this table is the *browsable source* the user picks
-- from. POST /api/workouts/exercise-catalog/:slug/add copies one row into
-- `workouts` (+ workout_category_map), so the two never fight over a schema.
--
-- Rows are written exclusively by the backend's service-role client, from
-- POST /api/workouts/exercise-catalog/import (admin-only), which fetches the
-- dataset JSON and upserts by `slug`.
--
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- The whole file is idempotent (safe to run twice). Backend code tolerates this
-- migration NOT having run: every route that touches the table maps Postgres'
-- undefined-table error to a 503 telling you to run migration 0013, rather than
-- a 500.

create extension if not exists "pgcrypto";

create table if not exists public.exercise_catalog (
  id uuid primary key default gen_random_uuid(),
  -- The dataset's own id (e.g. "3_4_Sit-Up"). Stable across dataset releases,
  -- so it is the upsert key and the add-to-library path param.
  slug text not null unique,
  name text not null,
  -- Dataset enums, stored as free text on purpose: a new value in an upstream
  -- release should import cleanly rather than violate a check constraint.
  -- Observed values at import time:
  --   category: strength | stretching | plyometrics | strongman | powerlifting
  --             | cardio | olympic weightlifting
  --   level:    beginner | intermediate | expert
  --   mechanic: compound | isolation | null
  --   force:    push | pull | static | null
  category text not null,
  level text,
  mechanic text,
  force text,
  -- equipment: bands | barbell | body only | cable | dumbbell | e-z curl bar |
  --            exercise ball | foam roll | kettlebells | machine |
  --            medicine ball | other | null
  equipment text,
  -- Lowercase dataset spellings ("lower back", "quadriceps"), not display
  -- names — the backend title-cases on the way into `workouts`.
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  instructions text[] not null default '{}',
  -- RELATIVE paths inside the dataset repo ("3_4_Sit-Up/0.jpg"). The client
  -- joins them onto the raw.githubusercontent.com prefix, so re-hosting the
  -- images later is a client-side change with no re-import.
  images text[] not null default '{}',
  source text not null default 'free-exercise-db',
  imported_at timestamptz not null default now()
);

-- The picker filters by category chip and searches by name; both are plain
-- equality / ilike in exercise-catalog.service.js. A btree on category covers
-- the chip, and the name ordering keeps the paginated list stable.
create index if not exists exercise_catalog_category_idx
  on public.exercise_catalog (category);

create index if not exists exercise_catalog_name_idx
  on public.exercise_catalog (name);

-- Row Level Security: catalog data is public read-only via the client, matching
-- workouts/workout_categories (migration 0003). Writes go through the backend's
-- service role key, which bypasses RLS, so no insert/update/delete policies are
-- defined here.
alter table public.exercise_catalog enable row level security;

drop policy if exists "exercise_catalog_public_read" on public.exercise_catalog;
create policy "exercise_catalog_public_read"
  on public.exercise_catalog for select
  using (true);
