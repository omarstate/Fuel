-- Fuel — link personal meal log entries back to the shared catalog meal they
-- were logged from, so we can compute per-catalog-meal stats (e.g. how many
-- times a meal has been logged, by how many people). Nullable: meals logged
-- without a catalog match (custom/free-form entries) simply have no link.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

alter table public.meals
  add column if not exists catalog_meal_id uuid references public.catalog_meals (id) on delete set null;

create index if not exists meals_catalog_meal_idx
  on public.meals (catalog_meal_id);
