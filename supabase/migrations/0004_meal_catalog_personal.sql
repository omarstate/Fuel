-- Fuel — personal meal catalog: adds the user's real-world meals, grouped
-- into categories that mirror how they actually track food (prepared meals,
-- batch-cooked staples, recurring daily meals, supplements, etc.), distinct
-- from the starter categories seeded in 0002_meal_catalog.sql.
-- Run this in your Supabase project: Dashboard → SQL Editor → paste → Run.
--
-- Note: catalog_meals.protein/carbs/fat are integer columns, so source
-- values given with a decimal gram (e.g. "1.5F", "37.45C") are rounded to
-- the nearest whole gram below.

insert into public.meal_categories (name, slug, description, sort_order)
values
  ('Meals & Prepared Foods',      'meals-prepared-foods',       'Delivery & pre-made meals',                7),
  ('Batch-Cooked / Home-Prepared','batch-cooked-home-prepared', 'Home-cooked staples by serving',           8),
  ('Recurring Meals',             'recurring-meals',            'Repeated daily meal totals',                9),
  ('Protein Supplements',         'protein-supplements',        'Bars, shakes & protein snacks',            10),
  ('Dairy & Yogurt',              'dairy-yogurt',                'Dairy, cheese & yogurt',                   11),
  ('Breads & Grains',             'breads-grains',               'Breads, toasts & grain-based cereals',     12),
  ('Snacks & Puffs',              'snacks-puffs',                'Puffs, rice cakes & chips',                13),
  ('Condiments & Extras',         'condiments-extras',           'Oils, spreads, fruit & small extras',      14)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Meals & Prepared Foods
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Really Good Honey Mustard Grilled Chicken Panini',
  (select id from public.meal_categories where slug = 'meals-prepared-foods'), 420, 37, 45, 10
where not exists (select 1 from public.catalog_meals where name = 'Really Good Honey Mustard Grilled Chicken Panini');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Breadfast honey mustard chicken',
  (select id from public.meal_categories where slug = 'meals-prepared-foods'), 495, 37, 51, 14
where not exists (select 1 from public.catalog_meals where name = 'Breadfast honey mustard chicken');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Breadfast spicy chicken sandwich',
  (select id from public.meal_categories where slug = 'meals-prepared-foods'), 505, 37, 48, 18
where not exists (select 1 from public.catalog_meals where name = 'Breadfast spicy chicken sandwich');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Talabat tuna sandwich',
  (select id from public.meal_categories where slug = 'meals-prepared-foods'), 390, 21, 42, 16
where not exists (select 1 from public.catalog_meals where name = 'Talabat tuna sandwich');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Talabat chicken honey mustard sandwich',
  (select id from public.meal_categories where slug = 'meals-prepared-foods'), 420, 28, 48, 12
where not exists (select 1 from public.catalog_meals where name = 'Talabat chicken honey mustard sandwich');

-- ---------------------------------------------------------------------------
-- Batch-Cooked / Home-Prepared
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Chicken batch per serving',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '130g', 279, 38, 8, 10
where not exists (select 1 from public.catalog_meals where name = 'Chicken batch per serving');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Potatoes batch per serving',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '100g', 237, 5, 43, 5
where not exists (select 1 from public.catalog_meals where name = 'Potatoes batch per serving');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select '150g air-fried potatoes',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '150g', 136, 3, 27, 3
where not exists (select 1 from public.catalog_meals where name = '150g air-fried potatoes');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select '150g basmati rice',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '150g', 240, 4, 45, 5
where not exists (select 1 from public.catalog_meals where name = '150g basmati rice');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select '2 baladi eggs scrambled',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '2 eggs', 140, 12, 1, 10
where not exists (select 1 from public.catalog_meals where name = '2 baladi eggs scrambled');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select '3 baladi eggs boiled',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '3 eggs', 203, 17, 1, 14
where not exists (select 1 from public.catalog_meals where name = '3 baladi eggs boiled');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Not fried chicken nuggets',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '100g', 162, 17, 18, 3
where not exists (select 1 from public.catalog_meals where name = 'Not fried chicken nuggets');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Not fried chicken strips',
  (select id from public.meal_categories where slug = 'batch-cooked-home-prepared'), '100g', 154, 18, 16, 2
where not exists (select 1 from public.catalog_meals where name = 'Not fried chicken strips');

-- ---------------------------------------------------------------------------
-- Recurring Meals
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Breakfast workdays',
  (select id from public.meal_categories where slug = 'recurring-meals'), 415, 37, 52, 9
where not exists (select 1 from public.catalog_meals where name = 'Breakfast workdays');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Breakfast weekends',
  (select id from public.meal_categories where slug = 'recurring-meals'), 373, 35, 33, 14
where not exists (select 1 from public.catalog_meals where name = 'Breakfast weekends');

-- ---------------------------------------------------------------------------
-- Protein Supplements
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'KeepGoing protein bar',
  (select id from public.meal_categories where slug = 'protein-supplements'), 232, 19, 22, 8
where not exists (select 1 from public.catalog_meals where name = 'KeepGoing protein bar');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'KeepGoing protein shake (water)',
  (select id from public.meal_categories where slug = 'protein-supplements'), 193, 31, 14, 2
where not exists (select 1 from public.catalog_meals where name = 'KeepGoing protein shake (water)');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'KeepGoing protein shake (milk)',
  (select id from public.meal_categories where slug = 'protein-supplements'), 194, 31, 14, 2
where not exists (select 1 from public.catalog_meals where name = 'KeepGoing protein shake (milk)');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'HiPro protein shake',
  (select id from public.meal_categories where slug = 'protein-supplements'), 187, 20, 18, 4
where not exists (select 1 from public.catalog_meals where name = 'HiPro protein shake');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'BYLD protein bar',
  (select id from public.meal_categories where slug = 'protein-supplements'), 246, 21, 27, 6
where not exists (select 1 from public.catalog_meals where name = 'BYLD protein bar');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Lychee protein bar',
  (select id from public.meal_categories where slug = 'protein-supplements'), 240, 20, 21, 9
where not exists (select 1 from public.catalog_meals where name = 'Lychee protein bar');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'ASN chocolate brownie',
  (select id from public.meal_categories where slug = 'protein-supplements'), 270, 16, 39, 6
where not exists (select 1 from public.catalog_meals where name = 'ASN chocolate brownie');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Real Choco Pops',
  (select id from public.meal_categories where slug = 'protein-supplements'), 120, 8, 18, 2
where not exists (select 1 from public.catalog_meals where name = 'Real Choco Pops');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Healthy chocolate spread',
  (select id from public.meal_categories where slug = 'protein-supplements'), '15g', 60, 4, 4, 3
where not exists (select 1 from public.catalog_meals where name = 'Healthy chocolate spread');

-- ---------------------------------------------------------------------------
-- Dairy & Yogurt
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Dina Farms cottage cheese',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), '100g', 106, 11, 3, 4
where not exists (select 1 from public.catalog_meals where name = 'Dina Farms cottage cheese');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Yopolis greek yogurt peach',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), 93, 11, 13, 0
where not exists (select 1 from public.catalog_meals where name = 'Yopolis greek yogurt peach');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Juhayna greek yogurt',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), 160, 12, 23, 3
where not exists (select 1 from public.catalog_meals where name = 'Juhayna greek yogurt');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Juhayna mixed berries yogurt cup',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), '180g', 164, 12, 23, 3
where not exists (select 1 from public.catalog_meals where name = 'Juhayna mixed berries yogurt cup');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Lamar 0% fat milk',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), '100ml', 32, 3, 5, 0
where not exists (select 1 from public.catalog_meals where name = 'Lamar 0% fat milk');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Domty light mozzarella',
  (select id from public.meal_categories where slug = 'dairy-yogurt'), '100g', 200, 22, 2, 12
where not exists (select 1 from public.catalog_meals where name = 'Domty light mozzarella');

-- ---------------------------------------------------------------------------
-- Breads & Grains
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Rich Bake protein toast',
  (select id from public.meal_categories where slug = 'breads-grains'), '1 slice', 70, 6, 9, 2
where not exists (select 1 from public.catalog_meals where name = 'Rich Bake protein toast');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Rich Bake tortilla bread',
  (select id from public.meal_categories where slug = 'breads-grains'), 250, 7, 53, 1
where not exists (select 1 from public.catalog_meals where name = 'Rich Bake tortilla bread');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Rich Bake pita bread',
  (select id from public.meal_categories where slug = 'breads-grains'), '1 pita', 116, 3, 26, 0
where not exists (select 1 from public.catalog_meals where name = 'Rich Bake pita bread');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Reef protein bread',
  (select id from public.meal_categories where slug = 'breads-grains'), 13, 5, 11, 1
where not exists (select 1 from public.catalog_meals where name = 'Reef protein bread');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Gedy bread',
  (select id from public.meal_categories where slug = 'breads-grains'), 98, 3, 19, 1
where not exists (select 1 from public.catalog_meals where name = 'Gedy bread');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Own protein chunk',
  (select id from public.meal_categories where slug = 'breads-grains'), '1 piece', 49, 4, 5, 2
where not exists (select 1 from public.catalog_meals where name = 'Own protein chunk');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Cerelac',
  (select id from public.meal_categories where slug = 'breads-grains'), '30g', 130, 5, 18, 4
where not exists (select 1 from public.catalog_meals where name = 'Cerelac');

-- ---------------------------------------------------------------------------
-- Snacks & Puffs
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Balance protein puffs',
  (select id from public.meal_categories where slug = 'snacks-puffs'), '70g', 280, 20, 43, 3
where not exists (select 1 from public.catalog_meals where name = 'Balance protein puffs');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Balance Sweet Corn protein puffs',
  (select id from public.meal_categories where slug = 'snacks-puffs'), '70g', 280, 15, 37, 9
where not exists (select 1 from public.catalog_meals where name = 'Balance Sweet Corn protein puffs');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Halo protein puffs',
  (select id from public.meal_categories where slug = 'snacks-puffs'), 160, 8, 21, 5
where not exists (select 1 from public.catalog_meals where name = 'Halo protein puffs');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Halo organic rice cakes',
  (select id from public.meal_categories where slug = 'snacks-puffs'), '1 cake', 27, 0, 6, 0
where not exists (select 1 from public.catalog_meals where name = 'Halo organic rice cakes');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Real Hummus chips full serving',
  (select id from public.meal_categories where slug = 'snacks-puffs'), '50g', 200, 8, 22, 5
where not exists (select 1 from public.catalog_meals where name = 'Real Hummus chips full serving');

-- ---------------------------------------------------------------------------
-- Condiments & Extras
-- ---------------------------------------------------------------------------
insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Extra virgin olive oil',
  (select id from public.meal_categories where slug = 'condiments-extras'), '2.5ml', 22, 0, 0, 3
where not exists (select 1 from public.catalog_meals where name = 'Extra virgin olive oil');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'ISIS honey',
  (select id from public.meal_categories where slug = 'condiments-extras'), '100g', 304, 0, 82, 0
where not exists (select 1 from public.catalog_meals where name = 'ISIS honey');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Dates',
  (select id from public.meal_categories where slug = 'condiments-extras'), '3 pieces', 60, 1, 18, 0
where not exists (select 1 from public.catalog_meals where name = 'Dates');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Jelly',
  (select id from public.meal_categories where slug = 'condiments-extras'), '1 cup', 36, 9, 0, 0
where not exists (select 1 from public.catalog_meals where name = 'Jelly');

insert into public.catalog_meals (name, category_id, serving_size, calories, protein, carbs, fat)
select 'Lychee orange juice',
  (select id from public.meal_categories where slug = 'condiments-extras'), '100ml', 40, 1, 8, 0
where not exists (select 1 from public.catalog_meals where name = 'Lychee orange juice');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Sunshine diet tuna can',
  (select id from public.meal_categories where slug = 'condiments-extras'), 140, 26, 2, 2
where not exists (select 1 from public.catalog_meals where name = 'Sunshine diet tuna can');

insert into public.catalog_meals (name, category_id, calories, protein, carbs, fat)
select 'Wonderfit chocolate ice cream',
  (select id from public.meal_categories where slug = 'condiments-extras'), 139, 6, 9, 9
where not exists (select 1 from public.catalog_meals where name = 'Wonderfit chocolate ice cream');
