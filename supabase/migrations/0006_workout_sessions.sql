-- Fuel — workout sessions: per-user session log (start/stop a workout,
-- log exercises + sets during it). Mirrors the meals per-user RLS pattern
-- from 0001_init_meals.sql: user_id is denormalized onto every table so
-- each RLS policy is a simple `auth.uid() = user_id` check.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

create extension if not exists "pgcrypto";

create table if not exists public.workout_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  category_id       uuid references public.workout_categories (id) on delete set null,
  category_name     text,   -- snapshot so history survives category deletion
  category_slug     text,   -- snapshot
  status            text not null default 'in_progress'
                      check (status in ('in_progress', 'completed')),
  started_at        timestamptz not null default now(),
  ended_at          timestamptz,
  duration_seconds  integer,   -- set on completion
  notes             text,
  created_at        timestamptz not null default now()
);

create table if not exists public.session_exercises (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.workout_sessions (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  workout_id  uuid references public.workouts (id) on delete set null,  -- catalog link when picked, null for custom
  name        text not null,   -- snapshot (catalog or custom name)
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.session_sets (
  id                   uuid primary key default gen_random_uuid(),
  session_exercise_id  uuid not null references public.session_exercises (id) on delete cascade,
  user_id              uuid not null references auth.users (id) on delete cascade,
  set_number           integer not null,
  weight               numeric(6,2),   -- kg, nullable
  reps                 integer,        -- nullable
  note                 text,
  created_at           timestamptz not null default now()
);

create index if not exists workout_sessions_user_started_idx
  on public.workout_sessions (user_id, started_at desc);

create index if not exists session_exercises_session_position_idx
  on public.session_exercises (session_id, position);

create index if not exists session_sets_exercise_set_idx
  on public.session_sets (session_exercise_id, set_number);

-- Row Level Security: each user can only see and modify their own rows.
alter table public.workout_sessions enable row level security;
alter table public.session_exercises enable row level security;
alter table public.session_sets enable row level security;

drop policy if exists "workout_sessions_select_own" on public.workout_sessions;
create policy "workout_sessions_select_own"
  on public.workout_sessions for select
  using (auth.uid() = user_id);

drop policy if exists "workout_sessions_insert_own" on public.workout_sessions;
create policy "workout_sessions_insert_own"
  on public.workout_sessions for insert
  with check (auth.uid() = user_id);

drop policy if exists "workout_sessions_update_own" on public.workout_sessions;
create policy "workout_sessions_update_own"
  on public.workout_sessions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "workout_sessions_delete_own" on public.workout_sessions;
create policy "workout_sessions_delete_own"
  on public.workout_sessions for delete
  using (auth.uid() = user_id);

drop policy if exists "session_exercises_select_own" on public.session_exercises;
create policy "session_exercises_select_own"
  on public.session_exercises for select
  using (auth.uid() = user_id);

drop policy if exists "session_exercises_insert_own" on public.session_exercises;
create policy "session_exercises_insert_own"
  on public.session_exercises for insert
  with check (auth.uid() = user_id);

drop policy if exists "session_exercises_update_own" on public.session_exercises;
create policy "session_exercises_update_own"
  on public.session_exercises for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "session_exercises_delete_own" on public.session_exercises;
create policy "session_exercises_delete_own"
  on public.session_exercises for delete
  using (auth.uid() = user_id);

drop policy if exists "session_sets_select_own" on public.session_sets;
create policy "session_sets_select_own"
  on public.session_sets for select
  using (auth.uid() = user_id);

drop policy if exists "session_sets_insert_own" on public.session_sets;
create policy "session_sets_insert_own"
  on public.session_sets for insert
  with check (auth.uid() = user_id);

drop policy if exists "session_sets_update_own" on public.session_sets;
create policy "session_sets_update_own"
  on public.session_sets for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "session_sets_delete_own" on public.session_sets;
create policy "session_sets_delete_own"
  on public.session_sets for delete
  using (auth.uid() = user_id);
