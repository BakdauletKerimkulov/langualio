-- ============================================================
-- Word Quiz: Security Hardening
-- 1. Set search_path on SECURITY DEFINER functions
-- 2. Add auth guard to upsert function
-- 3. Restrict RPC execution to authenticated role only
-- ============================================================

-- ── 1. Recreate get_todays_words() with search_path ──

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
  WHERE dws.active_date = ((now() AT TIME ZONE 'Asia/Almaty') - INTERVAL '2 hours')::date;
$$;

-- ── 2. Recreate upsert_word_learning_progress() with search_path + auth guard ──

CREATE OR REPLACE FUNCTION public.upsert_word_learning_progress(
  p_word_id uuid,
  p_correct_date date
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_dates jsonb;
  v_sorted_dates date[];
  v_chain_count int;
  v_prev_date date;
  v_curr_date date;
  v_is_learned boolean := false;
BEGIN
  -- Auth guard: reject unauthenticated calls
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Upsert: insert or update the row for current user + word
  INSERT INTO public.word_learning_progress (user_id, word_id, correct_count, last_correct_date, dates_correct, updated_at)
  VALUES (v_user_id, p_word_id, 1, p_correct_date, jsonb_build_array(p_correct_date::text), now())
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
  WHERE wlp.user_id = v_user_id AND wlp.word_id = p_word_id;

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
    WHERE user_id = v_user_id
      AND word_id = p_word_id
      AND learned_at IS NULL;
  END IF;
END;
$$;

-- ── 3. Restrict RPC execution to authenticated users only ──

REVOKE EXECUTE ON FUNCTION public.get_todays_words() FROM anon;
REVOKE EXECUTE ON FUNCTION public.upsert_word_learning_progress(uuid, date) FROM anon;

GRANT EXECUTE ON FUNCTION public.get_todays_words() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_word_learning_progress(uuid, date) TO authenticated;
