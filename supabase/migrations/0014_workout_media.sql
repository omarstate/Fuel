-- Fuel — workout media: carry the free-exercise-db demo photos and the full
-- step-by-step instructions across when a browsed exercise is added to the
-- curated `workouts` library (migration 0003).
--
-- Until now `addExerciseToWorkouts` copied only the text fields and squeezed
-- the dataset's instructions into a 240-char `description`, so the library card
-- had no thumbnail and there was nothing to show in a detail view. These two
-- columns are the same shape as their `exercise_catalog` counterparts
-- (migration 0013): `images` holds RELATIVE paths inside the dataset repo
-- ("Bench_Press/0.jpg") that clients join onto the
-- raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/ prefix
-- themselves, and `instructions` holds the numbered how-to steps verbatim.
--
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- The whole file is idempotent (safe to run twice). Backend code tolerates this
-- migration NOT having run: `rowToWorkout` defaults both to [], and the add
-- path retries its insert without the two columns when Postgres reports them
-- undefined — so adding an exercise keeps working, just without the media.

alter table public.workouts
  add column if not exists images text[] not null default '{}';

alter table public.workouts
  add column if not exists instructions text[] not null default '{}';
