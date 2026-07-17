-- Fuel — AI features: web-search meal lookup metadata on catalog_meals plus a
-- per-user, per-day cache of AI coach insights. Mirrors the per-user RLS
-- pattern from 0001_init_meals.sql / 0007_profiles.sql: a simple
-- `auth.uid() = user_id` check on every policy.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

-- ---------------------------------------------------------------------------
-- catalog_meals: AI provenance columns (all nullable — null means the meal was
-- human-entered rather than discovered by AI web search).
--   ai_source   'official' (values from the brand's own site) | 'estimate'
--   source_url  the grounding source the numbers came from
--   macro_ranges {"calories":[min,max],"protein":[min,max],
--                 "carbs":[min,max],"fat":[min,max]} when confidence = estimate
-- ---------------------------------------------------------------------------
alter table public.catalog_meals
  add column if not exists ai_source text check (ai_source in ('official','estimate')),
  add column if not exists source_url text,
  add column if not exists macro_ranges jsonb;

-- Seed the category AI-discovered meals land in (idempotent).
insert into public.meal_categories (name, slug, description, sort_order)
values ('AI Discovered', 'ai-discovered', 'Found with AI web search', 15)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- ai_insights: one cached coach summary per user per UTC day. Written by the
-- backend service role; users only ever read their own rows.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_insights (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  content    jsonb not null,
  model      text,
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

-- Row Level Security: each user can only see their own insights. Writes go
-- through the backend's service role key (which bypasses RLS), so select-own
-- is sufficient — insert/update policies are added for consistency with 0007.
alter table public.ai_insights enable row level security;

drop policy if exists "ai_insights_select_own" on public.ai_insights;
create policy "ai_insights_select_own"
  on public.ai_insights for select
  using (auth.uid() = user_id);

drop policy if exists "ai_insights_insert_own" on public.ai_insights;
create policy "ai_insights_insert_own"
  on public.ai_insights for insert
  with check (auth.uid() = user_id);

drop policy if exists "ai_insights_update_own" on public.ai_insights;
create policy "ai_insights_update_own"
  on public.ai_insights for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
