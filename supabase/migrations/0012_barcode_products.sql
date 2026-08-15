-- Fuel — shared barcode → nutrition cache for the scan feature.
-- Open Food Facts rate-limits per IP, and the Render-hosted backend shares its
-- egress IP with other tenants, so server-side lookups often come back 429.
-- This table is a read-through cache: successful lookups (fetched by the
-- backend, or reported by clients that fell back to calling OFF directly from
-- the device) are stored per barcode so repeat scans skip OFF entirely.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- The whole file is idempotent (safe to run twice). Backend code tolerates this
-- migration NOT having run: cache reads/writes fail soft and every lookup just
-- goes straight to Open Food Facts, exactly as before.

create table if not exists public.barcode_products (
  barcode text primary key,
  -- Nullable on purpose: OFF sometimes has macros for a product whose name
  -- only exists in a localized field we don't fetch. Those are still worth
  -- caching; the review UI lets the user type the name.
  name text,
  brand text,
  serving_size text not null default '',
  serving_grams numeric,
  -- Per-100g basis, matching the normalized BarcodeProduct DTO. Only usable
  -- products (calories > 0) are cached; "not found" is never cached so newly
  -- added OFF products show up on the next scan.
  calories integer not null default 0,
  protein integer not null default 0,
  carbs integer not null default 0,
  fat integer not null default 0,
  -- 'off' = fetched from Open Food Facts by the backend (authoritative);
  -- 'client' = reported by an app that called OFF directly after the backend
  -- was rate-limited. 'off' rows are never overwritten by 'client' reports.
  source text not null default 'off' check (source in ('off', 'client')),
  updated_at timestamptz not null default now()
);

-- Idempotency guard: an earlier draft of this migration declared name NOT
-- NULL. If that version was already run, `create table if not exists` above
-- won't touch the live column — drop the constraint explicitly.
alter table public.barcode_products alter column name drop not null;

-- Service-role only: the cache is read and written exclusively by the Express
-- backend. RLS on with no policies blocks anon/authenticated PostgREST access.
alter table public.barcode_products enable row level security;
