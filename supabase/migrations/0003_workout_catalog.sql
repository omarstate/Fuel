-- Fuel — workout catalog: shared workout types (categories) + a browsable
-- library of workouts. Unlike the meal catalog (one-to-many meal -> category),
-- workouts <-> categories is many-to-many via workout_category_map, so a
-- workout like "Barbell Row" can appear under both "Pull" and "Upper Body".
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

create extension if not exists "pgcrypto";

create table if not exists public.workout_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  description text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.workouts (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  description    text,
  primary_muscle text,
  equipment      text,
  target_sets    integer,
  target_reps    text,
  created_by     uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now()
);

-- Many-to-many join: a workout can belong to several categories/types
-- (e.g. Romanian Deadlift -> Legs, Lower Body, Pull) and a category holds
-- many workouts.
create table if not exists public.workout_category_map (
  workout_id  uuid not null references public.workouts (id) on delete cascade,
  category_id uuid not null references public.workout_categories (id) on delete cascade,
  primary key (workout_id, category_id)
);

create index if not exists workout_category_map_category_idx
  on public.workout_category_map (category_id);

create index if not exists workout_category_map_workout_idx
  on public.workout_category_map (workout_id);

-- Row Level Security: catalog data is public read-only via the client.
-- Writes go through the backend's Supabase service role key, which bypasses
-- RLS, so no insert/update/delete policies are defined here.
alter table public.workout_categories enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_category_map enable row level security;

drop policy if exists "workout_categories_public_read" on public.workout_categories;
create policy "workout_categories_public_read"
  on public.workout_categories for select
  using (true);

drop policy if exists "workouts_public_read" on public.workouts;
create policy "workouts_public_read"
  on public.workouts for select
  using (true);

drop policy if exists "workout_category_map_public_read" on public.workout_category_map;
create policy "workout_category_map_public_read"
  on public.workout_category_map for select
  using (true);

-- ---------------------------------------------------------------------------
-- Seed data (idempotent — safe to re-run)
-- ---------------------------------------------------------------------------

insert into public.workout_categories (name, slug, description, sort_order)
values
  ('Push',        'push',        'Chest, shoulders & triceps pressing movements', 1),
  ('Pull',        'pull',        'Back & biceps pulling movements',               2),
  ('Legs',        'legs',        'Quads, hamstrings, glutes & calves',            3),
  ('Upper Body',  'upper-body',  'All upper-body pushing and pulling',            4),
  ('Lower Body',  'lower-body',  'All lower-body strength work',                  5),
  ('Full Body',   'full-body',   'Compound movements that hit everything',        6),
  ('Core',        'core',        'Abs & midline stability',                       7)
on conflict (slug) do nothing;

-- Bench Press -> Push, Upper Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Bench Press', 'Flat barbell bench press for chest, shoulders and triceps',
  'Chest', 'Barbell', 4, '6-10'
where not exists (select 1 from public.workouts where name = 'Bench Press');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Bench Press' and c.slug in ('push', 'upper-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Overhead Press -> Push, Upper Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Overhead Press', 'Standing barbell press for shoulders and triceps',
  'Shoulders', 'Barbell', 4, '6-10'
where not exists (select 1 from public.workouts where name = 'Overhead Press');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Overhead Press' and c.slug in ('push', 'upper-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Barbell Row -> Pull, Upper Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Barbell Row', 'Bent-over barbell row for back thickness',
  'Back', 'Barbell', 4, '8-12'
where not exists (select 1 from public.workouts where name = 'Barbell Row');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Barbell Row' and c.slug in ('pull', 'upper-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Pull-up -> Pull, Upper Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Pull-up', 'Bodyweight vertical pull for back and biceps',
  'Back', 'Pull-up Bar', 4, '6-10'
where not exists (select 1 from public.workouts where name = 'Pull-up');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Pull-up' and c.slug in ('pull', 'upper-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Back Squat -> Legs, Lower Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Back Squat', 'Barbell back squat for quads and glutes',
  'Quads', 'Barbell', 5, '5-8'
where not exists (select 1 from public.workouts where name = 'Back Squat');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Back Squat' and c.slug in ('legs', 'lower-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Romanian Deadlift -> Legs, Lower Body, Pull
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Romanian Deadlift', 'Hip-hinge barbell movement for hamstrings and glutes',
  'Hamstrings', 'Barbell', 4, '8-12'
where not exists (select 1 from public.workouts where name = 'Romanian Deadlift');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Romanian Deadlift' and c.slug in ('legs', 'lower-body', 'pull')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Deadlift -> Pull, Lower Body, Full Body
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Deadlift', 'Conventional barbell deadlift, a full-body compound pull',
  'Back', 'Barbell', 3, '3-6'
where not exists (select 1 from public.workouts where name = 'Deadlift');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Deadlift' and c.slug in ('pull', 'lower-body', 'full-body')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Plank -> Core
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Plank', 'Isometric hold for core stability',
  'Core', 'Bodyweight', 3, '30-60s'
where not exists (select 1 from public.workouts where name = 'Plank');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Plank' and c.slug in ('core')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );

-- Hanging Leg Raise -> Core
insert into public.workouts (name, description, primary_muscle, equipment, target_sets, target_reps)
select 'Hanging Leg Raise', 'Hanging leg raise for lower abs',
  'Core', 'Pull-up Bar', 3, '10-15'
where not exists (select 1 from public.workouts where name = 'Hanging Leg Raise');

insert into public.workout_category_map (workout_id, category_id)
select w.id, c.id
from public.workouts w, public.workout_categories c
where w.name = 'Hanging Leg Raise' and c.slug in ('core')
  and not exists (
    select 1 from public.workout_category_map m
    where m.workout_id = w.id and m.category_id = c.id
  );
