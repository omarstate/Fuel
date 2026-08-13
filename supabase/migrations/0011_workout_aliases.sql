-- Fuel — spoken-name aliases on catalog workouts, for VOICE SET LOGGING.
-- Mid-workout the user speaks a set out loud ("بنش برس تمانين في تمانية"), the
-- phone transcribes it on-device and the backend parses it into exercises +
-- sets. Catalog exercise names are English, so aliases are the bridge from
-- Egyptian gym speech to the catalog: "بنش" → "Bench Press", "عقلة" → "Pull-up",
-- "تجديف" → "Barbell Row". Every confirmed voice log can teach the phrase the
-- user actually said back to the exercise it matched.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- The whole file is idempotent (safe to run twice). Backend code tolerates this
-- migration NOT having run: selects/inserts retry without the aliases column.

-- ---------------------------------------------------------------------------
-- workouts.aliases — alternative spoken names, never null (empty array means
-- "no aliases learned yet"). No RLS change needed: aliases live on `workouts`,
-- which already has its public-read policy from 0003_workout_catalog.sql, and
-- writes still only happen through the backend's service role key.
-- ---------------------------------------------------------------------------
alter table public.workouts
  add column if not exists aliases text[] not null default '{}';

-- GIN index so alias containment/overlap lookups stay cheap as the catalog grows.
create index if not exists workouts_aliases_idx
  on public.workouts using gin (aliases);

-- ---------------------------------------------------------------------------
-- Seed Egyptian aliases for the nine exercises seeded by 0003_workout_catalog.
-- Idempotent AND non-destructive: each update only fires when the row still has
-- an empty alias array, so re-running never clobbers aliases the app has since
-- learned from real voice logs.
-- ---------------------------------------------------------------------------

update public.workouts
set aliases = array['بنش', 'بنش برس', 'بنش بريس', 'بنش مستوي']
where name = 'Bench Press' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['كتف', 'برس كتف', 'ضغط كتف', 'بريس كتف']
where name = 'Overhead Press' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['تجديف', 'سحب بار', 'رو']
where name = 'Barbell Row' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['عقلة', 'عقل', 'بار عقلة']
where name = 'Pull-up' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['سكوات', 'اسكوات', 'سكوات خلفي']
where name = 'Back Squat' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['رومانيان', 'ديدليفت روماني', 'رفعة رومانية']
where name = 'Romanian Deadlift' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['ديدليفت', 'الرفعة الميتة', 'رفعة ميتة']
where name = 'Deadlift' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['بلانك', 'بلانك بطن']
where name = 'Plank' and coalesce(array_length(aliases, 1), 0) = 0;

update public.workouts
set aliases = array['رفع رجلين', 'رفع الرجلين معلق', 'بطن معلق']
where name = 'Hanging Leg Raise' and coalesce(array_length(aliases, 1), 0) = 0;
