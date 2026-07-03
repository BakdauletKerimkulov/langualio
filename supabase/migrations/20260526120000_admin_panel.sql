-- ============================================================
-- Admin Panel: Migration
-- 1. admin_emails whitelist table
-- 2. Trigger to set/remove admin role on auth.users
-- 3. Restructure daily_words to match WordEntry model
-- 4. Add status + created_by columns
-- 5. Updated RLS policies (admin full CRUD, users read published only)
-- 6. Update get_todays_words() RPC with status filter
-- ============================================================

-- ── 1. admin_emails table ──

CREATE TABLE public.admin_emails (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_emails ENABLE ROW LEVEL SECURITY;

-- No public access — only service role (migrations, Edge Functions) can read/write.

INSERT INTO public.admin_emails (email) VALUES
  ('bahaarmanov88@gmail.com'),
  ('test@test.com');

-- ── 2. Admin role trigger on auth.users ──

CREATE OR REPLACE FUNCTION public.handle_admin_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.admin_emails WHERE email = NEW.email) THEN
    NEW.raw_app_meta_data = jsonb_set(
      COALESCE(NEW.raw_app_meta_data, '{}'::jsonb),
      '{role}',
      '"admin"'
    );
  ELSE
    -- Remove role key if user is not in whitelist (handles revocation)
    NEW.raw_app_meta_data = COALESCE(NEW.raw_app_meta_data, '{}'::jsonb) - 'role';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_updated
  BEFORE UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_role();

-- ── 3. Restructure daily_words ──

-- Rename existing columns
ALTER TABLE public.daily_words RENAME COLUMN word_en TO word;
ALTER TABLE public.daily_words RENAME COLUMN word_ru TO translation;

-- Add new WordEntry columns
ALTER TABLE public.daily_words
  ADD COLUMN ipa text,
  ADD COLUMN part_of_speech text NOT NULL DEFAULT 'noun',
  ADD COLUMN level text NOT NULL DEFAULT 'a1',
  ADD COLUMN definition_en text,
  ADD COLUMN definition_ru text,
  ADD COLUMN example_en text NOT NULL DEFAULT '',
  ADD COLUMN example_ru text NOT NULL DEFAULT '',
  ADD COLUMN topic text,
  ADD COLUMN tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN alternative_translations jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN updated_at timestamptz;

-- ── 4. Add status and created_by ──

ALTER TABLE public.daily_words
  ADD COLUMN status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft', 'published', 'archived')),
  ADD COLUMN created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Existing seed words get status='published' via DEFAULT, created_by=NULL (no creator)

-- ── 5. RLS policy changes (atomic) ──

-- Drop old permissive SELECT policy
DROP POLICY "Authenticated users can read daily_words" ON public.daily_words;

-- Admin: full CRUD access
CREATE POLICY "Admins can manage all words"
  ON public.daily_words
  FOR ALL
  USING (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

-- Regular users: read-only, published words only
CREATE POLICY "Users can read published words"
  ON public.daily_words
  FOR SELECT
  TO authenticated
  USING (status = 'published');

-- ── 6. Update get_todays_words() RPC with status filter ──

CREATE OR REPLACE FUNCTION public.get_todays_words()
RETURNS SETOF public.daily_words
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT dw.*
  FROM public.daily_words dw
  INNER JOIN public.daily_word_sets dws ON dws.word_id = dw.id
  WHERE dws.active_date = ((now() AT TIME ZONE 'Asia/Almaty') - INTERVAL '2 hours')::date
    AND dw.status = 'published';
$$;

-- Keep existing GRANT/REVOKE from word_quiz_security migration
-- (get_todays_words is already restricted to authenticated role)
