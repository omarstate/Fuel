-- Fuel — initial schema: per-user meal log with Row Level Security.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

create extension if not exists "pgcrypto";

create table if not exists public.meals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  name         text not null,
  meal_type    text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  serving_size text,
  calories     integer not null default 0,
  protein      integer not null default 0,
  carbs        integer not null default 0,
  fat          integer not null default 0,
  logged_at    timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create index if not exists meals_user_logged_idx
  on public.meals (user_id, logged_at desc);

-- Row Level Security: each user can only see and modify their own rows.
alter table public.meals enable row level security;

drop policy if exists "meals_select_own" on public.meals;
create policy "meals_select_own"
  on public.meals for select
  using (auth.uid() = user_id);

drop policy if exists "meals_insert_own" on public.meals;
create policy "meals_insert_own"
  on public.meals for insert
  with check (auth.uid() = user_id);

drop policy if exists "meals_update_own" on public.meals;
create policy "meals_update_own"
  on public.meals for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "meals_delete_own" on public.meals;
create policy "meals_delete_own"
  on public.meals for delete
  using (auth.uid() = user_id);
