-- ============================================================
-- Word Quiz: Migration
-- Drop old practice tables, create word quiz tables, RPC functions, RLS policies
-- ============================================================

-- ── Drop Old Practice Tables ──

DROP TABLE IF EXISTS public.practice_attempts;
DROP TABLE IF EXISTS public.practice_questions;

-- ── 1. daily_words ──

CREATE TABLE public.daily_words (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  word_en text NOT NULL,
  word_ru text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.daily_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read daily_words"
  ON public.daily_words FOR SELECT TO authenticated USING (true);

-- ── 2. daily_word_sets ──

CREATE TABLE public.daily_word_sets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id uuid NOT NULL REFERENCES public.daily_words(id) ON DELETE CASCADE,
  active_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_daily_word_sets_active_date ON public.daily_word_sets(active_date);

ALTER TABLE public.daily_word_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read daily_word_sets"
  ON public.daily_word_sets FOR SELECT TO authenticated USING (true);

-- ── 3. word_quiz_attempts ──

CREATE TABLE public.word_quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  word_id uuid NOT NULL REFERENCES public.daily_words(id) ON DELETE CASCADE,
  selected_option text NOT NULL,
  is_correct boolean NOT NULL,
  language_direction text NOT NULL CHECK (language_direction IN ('en_to_ru', 'ru_to_en')),
  answered_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_word_quiz_attempts_user_answered
  ON public.word_quiz_attempts(user_id, answered_at);

CREATE INDEX idx_word_quiz_attempts_user_word_direction
  ON public.word_quiz_attempts(user_id, word_id, language_direction);

ALTER TABLE public.word_quiz_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own quiz attempts"
  ON public.word_quiz_attempts FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own quiz attempts"
  ON public.word_quiz_attempts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── 4. word_learning_progress ──

CREATE TABLE public.word_learning_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  word_id uuid NOT NULL REFERENCES public.daily_words(id) ON DELETE CASCADE,
  correct_count int NOT NULL DEFAULT 0,
  last_correct_date date,
  learned_at timestamptz,
  dates_correct jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, word_id)
);

ALTER TABLE public.word_learning_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own learning progress"
  ON public.word_learning_progress FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learning progress"
  ON public.word_learning_progress FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own learning progress"
  ON public.word_learning_progress FOR UPDATE USING (auth.uid() = user_id);

-- ── 5. RPC: get_todays_words() ──

CREATE OR REPLACE FUNCTION public.get_todays_words()
RETURNS SETOF public.daily_words
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT dw.*
  FROM public.daily_words dw
  INNER JOIN public.daily_word_sets dws ON dws.word_id = dw.id
  WHERE dws.active_date = ((now() AT TIME ZONE 'Asia/Almaty') - INTERVAL '2 hours')::date;
$$;

-- ── 6. RPC: upsert_word_learning_progress(p_word_id, p_correct_date) ──

CREATE OR REPLACE FUNCTION public.upsert_word_learning_progress(
  p_word_id uuid,
  p_correct_date date
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dates jsonb;
  v_sorted_dates date[];
  v_chain_count int;
  v_prev_date date;
  v_curr_date date;
  v_is_learned boolean := false;
BEGIN
  -- Upsert: insert or update the row for current user + word
  INSERT INTO public.word_learning_progress (user_id, word_id, correct_count, last_correct_date, dates_correct, updated_at)
  VALUES (auth.uid(), p_word_id, 1, p_correct_date, jsonb_build_array(p_correct_date::text), now())
  ON CONFLICT (user_id, word_id) DO UPDATE SET
    correct_count = word_learning_progress.correct_count + 1,
    last_correct_date = p_correct_date,
    dates_correct = (
      CASE
        WHEN word_learning_progress.dates_correct @> jsonb_build_array(p_correct_date::text)
        THEN word_learning_progress.dates_correct
        ELSE word_learning_progress.dates_correct || jsonb_build_array(p_correct_date::text)
      END
    ),
    updated_at = now()
  WHERE word_learning_progress.learned_at IS NULL;

  -- Fetch the updated dates_correct for learned-check
  SELECT wlp.dates_correct INTO v_dates
  FROM public.word_learning_progress wlp
  WHERE wlp.user_id = auth.uid() AND wlp.word_id = p_word_id;

  -- Parse dates and sort
  SELECT ARRAY(
    SELECT (d.value #>> '{}')::date
    FROM jsonb_array_elements(v_dates) AS d(value)
    ORDER BY (d.value #>> '{}')::date
  ) INTO v_sorted_dates;

  -- Greedy chain algorithm: chain dates with 1-3 day gaps
  IF array_length(v_sorted_dates, 1) >= 3 THEN
    v_chain_count := 1;
    v_prev_date := v_sorted_dates[1];

    FOR i IN 2 .. array_length(v_sorted_dates, 1) LOOP
      v_curr_date := v_sorted_dates[i];
      IF (v_curr_date - v_prev_date) BETWEEN 1 AND 3 THEN
        v_chain_count := v_chain_count + 1;
        IF v_chain_count >= 3 THEN
          v_is_learned := true;
          EXIT;
        END IF;
      ELSIF v_curr_date != v_prev_date THEN
        -- Gap too large, reset chain
        v_chain_count := 1;
      END IF;
      v_prev_date := v_curr_date;
    END LOOP;
  END IF;

  -- Mark as learned if newly learned
  IF v_is_learned THEN
    UPDATE public.word_learning_progress
    SET learned_at = now(), updated_at = now()
    WHERE user_id = auth.uid()
      AND word_id = p_word_id
      AND learned_at IS NULL;
  END IF;
END;
$$;

-- ── 7. Seed data for development/testing ──

INSERT INTO public.daily_words (id, word_en, word_ru) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Apple', 'Яблоко'),
  ('a0000000-0000-0000-0000-000000000002', 'House', 'Дом'),
  ('a0000000-0000-0000-0000-000000000003', 'Cat', 'Кот'),
  ('a0000000-0000-0000-0000-000000000004', 'Dog', 'Собака'),
  ('a0000000-0000-0000-0000-000000000005', 'Book', 'Книга'),
  ('a0000000-0000-0000-0000-000000000006', 'Water', 'Вода'),
  ('a0000000-0000-0000-0000-000000000007', 'Sun', 'Солнце'),
  ('a0000000-0000-0000-0000-000000000008', 'Moon', 'Луна'),
  ('a0000000-0000-0000-0000-000000000009', 'Tree', 'Дерево'),
  ('a0000000-0000-0000-0000-000000000010', 'Window', 'Окно'),
  ('a0000000-0000-0000-0000-000000000011', 'Door', 'Дверь'),
  ('a0000000-0000-0000-0000-000000000012', 'Table', 'Стол'),
  ('a0000000-0000-0000-0000-000000000013', 'Chair', 'Стул'),
  ('a0000000-0000-0000-0000-000000000014', 'Phone', 'Телефон'),
  ('a0000000-0000-0000-0000-000000000015', 'Car', 'Машина'),
  ('a0000000-0000-0000-0000-000000000016', 'Friend', 'Друг'),
  ('a0000000-0000-0000-0000-000000000017', 'Time', 'Время'),
  ('a0000000-0000-0000-0000-000000000018', 'School', 'Школа'),
  ('a0000000-0000-0000-0000-000000000019', 'Food', 'Еда'),
  ('a0000000-0000-0000-0000-000000000020', 'City', 'Город');

-- Assign all 20 words to today's date (Almaty timezone, -2h offset)
INSERT INTO public.daily_word_sets (word_id, active_date)
SELECT id, ((now() AT TIME ZONE 'Asia/Almaty') - INTERVAL '2 hours')::date
FROM public.daily_words;
