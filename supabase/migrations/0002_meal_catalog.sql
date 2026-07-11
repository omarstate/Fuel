-- Fuel — meal catalog: shared categories + a browsable/searchable meal
-- catalog, distinct from the per-user meal log created in 0001_init_meals.sql.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.

create extension if not exists "pgcrypto";

create table if not exists public.meal_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  description text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.catalog_meals (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text,
  category_id  uuid references public.meal_categories (id) on delete set null,
  serving_size text,
  calories     integer not null default 0,
  protein      integer not null default 0,
  carbs        integer not null default 0,
  fat          integer not null default 0,
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists catalog_meals_category_idx
  on public.catalog_meals (category_id);

-- Row Level Security: catalog data is public read-only via the client.
-- Writes go through the backend's Supabase service role key, which bypasses
-- RLS, so no insert/update/delete policies are defined here.
alter table public.meal_categories enable row level security;
alter table public.catalog_meals enable row level security;

drop policy if exists "categories_public_read" on public.meal_categories;
create policy "categories_public_read"
  on public.meal_categories for select
  using (true);

drop policy if exists "catalog_public_read" on public.catalog_meals;
create policy "catalog_public_read"
  on public.catalog_meals for select
  using (true);

-- ---------------------------------------------------------------------------
-- Seed data (idempotent — safe to re-run)
-- ---------------------------------------------------------------------------

insert into public.meal_categories (name, slug, description, sort_order)
values
  ('Breakfast',     'breakfast',     'Meals to start your day',        1),
  ('Lunch',         'lunch',         'Midday meals',                   2),
  ('Dinner',        'dinner',        'Evening meals',                  3),
  ('Snacks',        'snacks',        'Light bites between meals',      4),
  ('Drinks',        'drinks',        'Shakes, smoothies & beverages',  5),
  ('High-Protein',  'high-protein',  'Protein-forward meals',          6)
on conflict (slug) do nothing;

-- Breakfast
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Oats, eggs & banana', 'Rolled oats with two eggs and a banana on the side',
  (select id from public.meal_categories where slug = 'breakfast'),
  '1 bowl + 1 banana', 480, 24, 62, 14
where not exists (select 1 from public.catalog_meals where name = 'Oats, eggs & banana');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Greek yogurt & granola', 'Greek yogurt topped with granola and honey',
  (select id from public.meal_categories where slug = 'breakfast'),
  '1 cup', 350, 20, 45, 9
where not exists (select 1 from public.catalog_meals where name = 'Greek yogurt & granola');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Avocado toast & egg', 'Sourdough toast with mashed avocado and a fried egg',
  (select id from public.meal_categories where slug = 'breakfast'),
  '2 slices', 420, 17, 38, 22
where not exists (select 1 from public.catalog_meals where name = 'Avocado toast & egg');

-- Lunch
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Turkey & avocado wrap', 'Whole wheat wrap with turkey, avocado and greens',
  (select id from public.meal_categories where slug = 'lunch'),
  '1 wrap', 520, 32, 45, 22
where not exists (select 1 from public.catalog_meals where name = 'Turkey & avocado wrap');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Chicken caesar salad', 'Grilled chicken over romaine with caesar dressing',
  (select id from public.meal_categories where slug = 'lunch'),
  '1 plate', 460, 38, 18, 26
where not exists (select 1 from public.catalog_meals where name = 'Chicken caesar salad');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Quinoa veggie bowl', 'Quinoa with roasted vegetables and tahini dressing',
  (select id from public.meal_categories where slug = 'lunch'),
  '1 bowl', 440, 14, 58, 16
where not exists (select 1 from public.catalog_meals where name = 'Quinoa veggie bowl');

-- Dinner
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Salmon, rice & broccoli', 'Baked salmon fillet with steamed rice and broccoli',
  (select id from public.meal_categories where slug = 'dinner'),
  '1 plate', 560, 40, 48, 22
where not exists (select 1 from public.catalog_meals where name = 'Salmon, rice & broccoli');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Beef stir-fry & noodles', 'Lean beef strips stir-fried with vegetables and noodles',
  (select id from public.meal_categories where slug = 'dinner'),
  '1 plate', 610, 36, 62, 20
where not exists (select 1 from public.catalog_meals where name = 'Beef stir-fry & noodles');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Baked chicken & sweet potato', 'Oven-baked chicken thigh with roasted sweet potato',
  (select id from public.meal_categories where slug = 'dinner'),
  '1 plate', 530, 42, 44, 18
where not exists (select 1 from public.catalog_meals where name = 'Baked chicken & sweet potato');

-- Snacks
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Apple & peanut butter', 'Sliced apple with a scoop of peanut butter',
  (select id from public.meal_categories where slug = 'snacks'),
  '1 apple + 2 tbsp', 260, 7, 30, 13
where not exists (select 1 from public.catalog_meals where name = 'Apple & peanut butter');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Mixed nuts', 'A small handful of mixed nuts',
  (select id from public.meal_categories where slug = 'snacks'),
  '1 oz', 170, 6, 6, 15
where not exists (select 1 from public.catalog_meals where name = 'Mixed nuts');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Rice cakes & cottage cheese', 'Rice cakes topped with cottage cheese',
  (select id from public.meal_categories where slug = 'snacks'),
  '2 cakes', 210, 15, 24, 4
where not exists (select 1 from public.catalog_meals where name = 'Rice cakes & cottage cheese');

-- Drinks
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Whey protein shake', 'Whey protein blended with milk and ice',
  (select id from public.meal_categories where slug = 'drinks'),
  '1 shake', 220, 30, 12, 4
where not exists (select 1 from public.catalog_meals where name = 'Whey protein shake');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Berry banana smoothie', 'Mixed berries, banana and yogurt blended smoothie',
  (select id from public.meal_categories where slug = 'drinks'),
  '16 oz', 280, 10, 54, 4
where not exists (select 1 from public.catalog_meals where name = 'Berry banana smoothie');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Green smoothie', 'Spinach, mango and almond milk smoothie',
  (select id from public.meal_categories where slug = 'drinks'),
  '16 oz', 190, 5, 38, 3
where not exists (select 1 from public.catalog_meals where name = 'Green smoothie');

-- High-Protein
insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Grilled chicken & rice bowl', 'Grilled chicken breast over rice with vegetables',
  (select id from public.meal_categories where slug = 'high-protein'),
  '1 bowl', 540, 48, 52, 12
where not exists (select 1 from public.catalog_meals where name = 'Grilled chicken & rice bowl');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Egg white omelet & turkey bacon', 'Egg white omelet with turkey bacon and spinach',
  (select id from public.meal_categories where slug = 'high-protein'),
  '1 plate', 320, 40, 8, 12
where not exists (select 1 from public.catalog_meals where name = 'Egg white omelet & turkey bacon');

insert into public.catalog_meals (name, description, category_id, serving_size, calories, protein, carbs, fat)
select 'Steak & cottage cheese', 'Lean sirloin steak with a side of cottage cheese',
  (select id from public.meal_categories where slug = 'high-protein'),
  '1 plate', 480, 52, 10, 24
where not exists (select 1 from public.catalog_meals where name = 'Steak & cottage cheese');
