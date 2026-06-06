-- ============================================================
-- Migration: Restructure daily_words — flat meaning fields → JSONB meanings array
-- 1. Add meanings JSONB column
-- 2. Populate from existing flat columns
-- 3. Drop old flat columns
-- 4. Add non-empty array constraint
-- ============================================================

-- ── 1. Add meanings column (nullable temporarily for migration) ──

ALTER TABLE public.daily_words
  ADD COLUMN meanings jsonb;

-- ── 2. Populate meanings from existing flat columns ──

UPDATE public.daily_words
SET meanings = jsonb_build_array(
  jsonb_build_object(
    'part_of_speech', COALESCE(part_of_speech, 'noun'),
    'translation', COALESCE(translation, ''),
    'alternative_translations', COALESCE(alternative_translations, '[]'::jsonb),
    'definition_en', definition_en,
    'definition_ru', definition_ru,
    'example_en', COALESCE(example_en, ''),
    'example_ru', COALESCE(example_ru, '')
  )
);

-- ── 3. Make meanings NOT NULL now that all rows are populated ──

ALTER TABLE public.daily_words
  ALTER COLUMN meanings SET NOT NULL;

-- ── 4. Drop old flat columns ──

ALTER TABLE public.daily_words
  DROP COLUMN translation,
  DROP COLUMN part_of_speech,
  DROP COLUMN alternative_translations,
  DROP COLUMN definition_en,
  DROP COLUMN definition_ru,
  DROP COLUMN example_en,
  DROP COLUMN example_ru;

-- ── 5. Add constraint: meanings must be a non-empty array ──

ALTER TABLE public.daily_words
  ADD CONSTRAINT meanings_non_empty CHECK (jsonb_array_length(meanings) > 0);
