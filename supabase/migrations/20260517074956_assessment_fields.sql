-- ============================================================
-- Migration: Assessment fields for registration flow
-- Rename name → nickname, add cefr_level and assessment_completed
-- ============================================================

-- 1. Rename column name → nickname
ALTER TABLE public.profiles RENAME COLUMN name TO nickname;

-- 2. Add assessment fields
ALTER TABLE public.profiles
  ADD COLUMN cefr_level int,
  ADD COLUMN assessment_completed boolean NOT NULL DEFAULT false;

-- 3. Grandfather existing users — they should not be forced to take the test
UPDATE public.profiles SET assessment_completed = true;

-- 4. Update trigger to read nickname from user metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname)
  VALUES (new.id, coalesce(new.raw_user_meta_data->>'nickname', ''));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
