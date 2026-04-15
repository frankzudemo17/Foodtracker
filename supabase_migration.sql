-- ============================================================
-- Aufgetischt — Supabase Migration v2.3
-- ============================================================
-- Reihenfolge: 1) Neue Tabellen, 2) FK + Constraints, 3) Indexes,
--              4) Profile-Erweiterungen, 5) RLS-Policies
-- Idempotent geschrieben (IF NOT EXISTS / DROP IF EXISTS).
-- Vor dem Einspielen: Backup ziehen.
-- ============================================================

-- =================================================
-- 1) NEUE TABELLEN (Wasser, Favoriten)
-- =================================================

CREATE TABLE IF NOT EXISTS public.water_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_date date NOT NULL,
  amount_ml   integer NOT NULL CHECK (amount_ml >= 0 AND amount_ml <= 20000),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_water_log_user_date UNIQUE (user_id, logged_date)
);

CREATE TABLE IF NOT EXISTS public.favorites (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  food_name       text NOT NULL,
  brand           text,
  kcal_per_100    numeric(8,2) NOT NULL DEFAULT 0,
  protein_per_100 numeric(6,2) NOT NULL DEFAULT 0,
  carbs_per_100   numeric(6,2) NOT NULL DEFAULT 0,
  fat_per_100     numeric(6,2) NOT NULL DEFAULT 0,
  image_url       text,
  barcode         text,
  off_id          text,
  unit_hint       text DEFAULT 'g' CHECK (unit_hint IN ('g','ml','Stk','Portion')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_favorites_user_created
  ON public.favorites (user_id, created_at DESC);

-- =================================================
-- 2) PROFILE: Fasten-Fenster ergänzen
-- =================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fasting_window_hours integer
    DEFAULT 16
    CHECK (fasting_window_hours BETWEEN 8 AND 23);

-- Theme-Constraint nachrüsten
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_theme;
ALTER TABLE public.profiles ADD CONSTRAINT chk_theme
  CHECK (theme IS NULL OR theme IN ('light','dark','system'));

-- Numerische Sanity-Checks
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_kcal_goal;
ALTER TABLE public.profiles ADD CONSTRAINT chk_kcal_goal
  CHECK (daily_kcal_goal IS NULL OR (daily_kcal_goal BETWEEN 500 AND 9999));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_height_pos;
ALTER TABLE public.profiles ADD CONSTRAINT chk_height_pos
  CHECK (height_cm IS NULL OR height_cm BETWEEN 50 AND 250);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_weight_pos;
ALTER TABLE public.profiles ADD CONSTRAINT chk_weight_pos
  CHECK (current_weight_kg IS NULL OR current_weight_kg BETWEEN 20 AND 400);

-- =================================================
-- 3) FOOD_ENTRIES: amount auf NUMERIC (für 0.5 Portionen)
-- =================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='food_entries'
      AND column_name='amount' AND data_type='integer'
  ) THEN
    ALTER TABLE public.food_entries
      ALTER COLUMN amount TYPE numeric(10,3) USING amount::numeric;
  END IF;
END$$;

-- =================================================
-- 4) WEIGHT_LOG: UNIQUE-Constraint für Upsert
-- =================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_weight_log_user_date'
  ) THEN
    ALTER TABLE public.weight_log
      ADD CONSTRAINT uq_weight_log_user_date UNIQUE (user_id, logged_date);
  END IF;
END$$;

-- =================================================
-- 5) INDEXES (Performance)
-- =================================================

CREATE INDEX IF NOT EXISTS idx_food_entries_user_date_created
  ON public.food_entries (user_id, entry_date, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_food_entries_user_created_desc
  ON public.food_entries (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_weight_log_user_date
  ON public.weight_log (user_id, logged_date ASC);

CREATE INDEX IF NOT EXISTS idx_recipes_user_created
  ON public.recipes (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_recipes_public_created
  ON public.recipes (is_public, created_at DESC)
  WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_water_log_user_date
  ON public.water_log (user_id, logged_date);

-- Optional: Trigram-Suche für custom_foods (nur sinnvoll bei vielen Einträgen)
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE INDEX IF NOT EXISTS idx_custom_foods_name_trgm
--   ON public.custom_foods USING gin (food_name gin_trgm_ops);

-- =================================================
-- 6) RLS aktivieren (FALLS NOCH NICHT GESCHEHEN — KRITISCH!)
-- =================================================

ALTER TABLE public.profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_foods  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_log    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites     ENABLE ROW LEVEL SECURITY;

-- =================================================
-- 7) RLS POLICIES (Owner-Only + Public Recipes)
-- =================================================

-- profiles
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE USING (id = (SELECT auth.uid()));

-- food_entries
DROP POLICY IF EXISTS "entries_all_own" ON public.food_entries;
CREATE POLICY "entries_all_own" ON public.food_entries
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- custom_foods
DROP POLICY IF EXISTS "custom_foods_all_own" ON public.custom_foods;
CREATE POLICY "custom_foods_all_own" ON public.custom_foods
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- weight_log
DROP POLICY IF EXISTS "weight_log_all_own" ON public.weight_log;
CREATE POLICY "weight_log_all_own" ON public.weight_log
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- water_log
DROP POLICY IF EXISTS "water_log_all_own" ON public.water_log;
CREATE POLICY "water_log_all_own" ON public.water_log
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- favorites
DROP POLICY IF EXISTS "favorites_all_own" ON public.favorites;
CREATE POLICY "favorites_all_own" ON public.favorites
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- recipes — eigene IMMER, fremde NUR wenn is_public
DROP POLICY IF EXISTS "recipes_select" ON public.recipes;
CREATE POLICY "recipes_select" ON public.recipes
  FOR SELECT USING (
    user_id = (SELECT auth.uid()) OR is_public = true
  );

DROP POLICY IF EXISTS "recipes_insert_own" ON public.recipes;
CREATE POLICY "recipes_insert_own" ON public.recipes
  FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "recipes_update_own" ON public.recipes;
CREATE POLICY "recipes_update_own" ON public.recipes
  FOR UPDATE USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "recipes_delete_own" ON public.recipes;
CREATE POLICY "recipes_delete_own" ON public.recipes
  FOR DELETE USING (user_id = (SELECT auth.uid()));

-- =================================================
-- 8) AUTH-USER LÖSCHUNG (Edge Function nötig)
-- =================================================
-- Vollständige Account-Löschung erfordert eine Supabase Edge Function
-- mit SERVICE_ROLE_KEY, die supabase.auth.admin.deleteUser(uid) aufruft.
-- Der Anon-Key kann das nicht.
-- Anleitung: https://supabase.com/docs/guides/auth/managing-user-data#delete-user
-- ============================================================
