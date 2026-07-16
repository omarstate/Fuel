-- Fuel — user profiles: personal data + computed daily calorie/macro targets,
-- collected once during onboarding and editable afterward. Mirrors the
-- per-user RLS pattern from 0001_init_meals.sql: a simple `auth.uid() = user_id`
-- check on every policy.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

create table if not exists public.profiles (
  user_id         uuid primary key references auth.users (id) on delete cascade,
  sex             text not null check (sex in ('male','female')),
  age             integer not null check (age between 13 and 120),
  height_cm       numeric(5,1) not null check (height_cm between 90 and 260),
  weight_kg       numeric(5,1) not null check (weight_kg between 30 and 400),
  goal_weight_kg  numeric(5,1) not null check (goal_weight_kg between 30 and 400),
  activity_level  text not null check (activity_level in ('sedentary','light','moderate','very','extra')),
  pace            text not null check (pace in ('mild','standard','aggressive')),
  target_calories integer not null,
  target_protein  integer not null,
  target_carbs    integer not null,
  target_fat      integer not null,
  onboarded_at    timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Row Level Security: each user can only see and modify their own profile.
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
