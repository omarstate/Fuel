-- Fuel — simplify meal categories down to a small "main" set. The personal
-- catalog in 0004 and the AI-discovered bucket in 0008 fanned out into many
-- fine-grained categories; this consolidates everything into the seven main
-- ones (breakfast, lunch, dinner, snacks, beverages, desserts, ai-discovered).
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- Order matters and the whole file is idempotent (safe to run twice):
--   1. ensure the keep-set exists + normalize naming/sort,
--   2. remap meals off the categories being removed (old slug → new slug),
--   3. safety net: sweep any leftover non-keep-set meal into snacks,
--   4. delete the now-empty removed categories.
-- catalog_meals.category_id is `on delete set null`, but after steps 2–3 no
-- meal points at a removed category, so nothing is left nulled.

-- ---------------------------------------------------------------------------
-- 1. Keep-set: ensure it exists, normalize naming and sort order.
-- ---------------------------------------------------------------------------
insert into public.meal_categories (name, slug, description, sort_order)
values ('Desserts', 'desserts', 'Sweets & desserts', 6)
on conflict (slug) do nothing;

-- 'drinks' becomes the "Beverages" bucket.
update public.meal_categories
  set name = 'Beverages', description = 'Drinks, shakes & smoothies', sort_order = 5
  where slug = 'drinks';

update public.meal_categories set sort_order = 1 where slug = 'breakfast';
update public.meal_categories set sort_order = 2 where slug = 'lunch';
update public.meal_categories set sort_order = 3 where slug = 'dinner';
update public.meal_categories set sort_order = 4 where slug = 'snacks';
update public.meal_categories set sort_order = 6 where slug = 'desserts';
update public.meal_categories set sort_order = 7 where slug = 'ai-discovered';

-- ---------------------------------------------------------------------------
-- 2. Remap meals off the categories being removed (old slug → new slug).
--    Each UPDATE joins meal_categories twice: once for the old id (to match),
--    once for the new id (to set). No-op once the old category is gone.
-- ---------------------------------------------------------------------------
update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'high-protein' and newc.slug = 'dinner';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'meals-prepared-foods' and newc.slug = 'lunch';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'recurring-meals' and newc.slug = 'lunch';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'batch-cooked-home-prepared' and newc.slug = 'dinner';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'protein-supplements' and newc.slug = 'snacks';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'snacks-puffs' and newc.slug = 'snacks';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'condiments-extras' and newc.slug = 'snacks';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'dairy-yogurt' and newc.slug = 'breakfast';

update public.catalog_meals cm
  set category_id = newc.id
  from public.meal_categories oldc, public.meal_categories newc
  where cm.category_id = oldc.id and oldc.slug = 'breads-grains' and newc.slug = 'breakfast';

-- ---------------------------------------------------------------------------
-- 3. Safety net: any meal still pointing at a category outside the keep set
--    (e.g. a future/unknown category, or one missed above) → snacks.
-- ---------------------------------------------------------------------------
update public.catalog_meals cm
  set category_id = (select id from public.meal_categories where slug = 'snacks')
  where cm.category_id is not null
    and cm.category_id not in (
      select id from public.meal_categories
      where slug in ('breakfast','lunch','dinner','snacks','drinks','desserts','ai-discovered')
    );

-- ---------------------------------------------------------------------------
-- 4. Delete the now-empty removed categories.
-- ---------------------------------------------------------------------------
delete from public.meal_categories
  where slug not in ('breakfast','lunch','dinner','snacks','drinks','desserts','ai-discovered');
