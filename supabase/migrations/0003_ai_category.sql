-- Fuel — add the "AI" meal category. Meals estimated by the AI assistant are
-- saved into the shared catalog under this category so they become browsable,
-- reusable entries (in addition to being logged to the user's day).
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

insert into public.meal_categories (name, slug, description, sort_order)
values
  ('AI', 'ai', 'Meals estimated by the AI assistant', 7)
on conflict (slug) do nothing;
