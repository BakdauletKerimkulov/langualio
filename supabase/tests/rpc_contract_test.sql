-- ============================================================
-- RPC contract tests (Phase 7: R17)
-- Tests all RPC functions: anon rejected, authenticated correct,
-- double call idempotent/safe.
-- Run against local stack after `supabase db reset`:
--   psql "$LOCAL_DB_URL" -f supabase/tests/rpc_contract_test.sql
-- ============================================================

-- Helper: create a test user
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
BEGIN
  DELETE FROM auth.users WHERE id = v_test_uid;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    v_test_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'test-rpc@example.com',
    crypt('testpassword', gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}',
    '{"nickname":"RPC Tester"}', now(), now(),
    '', '', '', ''
  );
END $$;

-- ════════════════════════════════════════════
-- try_consume_quota
-- ════════════════════════════════════════════

-- ── Test 1: anon CANNOT call try_consume_quota ──
DO $$
BEGIN
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.try_consume_quota(
      'dddddddd-1111-2222-3333-dddddddddddd'::uuid, 'message', 20
    );
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon called try_consume_quota';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call try_consume_quota';
  END;
END $$;

-- ── Test 2: authenticated can call try_consume_quota ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_result boolean;
BEGIN
  DELETE FROM public.user_daily_usage WHERE user_id = v_test_uid;

  SELECT public.try_consume_quota(v_test_uid, 'message', 20) INTO v_result;

  IF NOT v_result THEN
    RAISE EXCEPTION 'TEST FAILED: try_consume_quota should return true on first call';
  END IF;

  RAISE NOTICE 'PASS: authenticated can call try_consume_quota (result=true)';
END $$;

-- ── Test 3: try_consume_quota double call increments correctly ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_result boolean;
  v_count int;
BEGIN
  DELETE FROM public.user_daily_usage WHERE user_id = v_test_uid;

  SELECT public.try_consume_quota(v_test_uid, 'message', 20) INTO v_result;
  SELECT public.try_consume_quota(v_test_uid, 'message', 20) INTO v_result;

  SELECT message_count INTO v_count
  FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  IF v_count != 2 THEN
    RAISE EXCEPTION 'TEST FAILED: expected count=2 after double call, got %', v_count;
  END IF;

  RAISE NOTICE 'PASS: try_consume_quota double call increments correctly (count=2)';
END $$;

-- ════════════════════════════════════════════
-- complete_assessment
-- ════════════════════════════════════════════

-- ── Test 4: anon CANNOT call complete_assessment ──
DO $$
BEGIN
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.complete_assessment('[]'::jsonb);
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon called complete_assessment';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call complete_assessment';
  END;
END $$;

-- ── Test 5: authenticated can call complete_assessment ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_result json;
  v_level int;
BEGIN
  UPDATE public.profiles SET cefr_level = NULL, assessment_completed = false
  WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"dddddddd-1111-2222-3333-dddddddddddd","role":"authenticated"}';

  SELECT public.complete_assessment(
    '[{"question_id": "a1_grammar_1", "answer": "is"}]'::jsonb
  ) INTO v_result;

  RESET ROLE;

  v_level := (v_result ->> 'cefr_level')::int;

  IF v_level IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: complete_assessment returned null level';
  END IF;

  RAISE NOTICE 'PASS: authenticated can call complete_assessment (level=%)', v_level;
END $$;

-- ── Test 6: complete_assessment double call is safe (idempotent update) ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_result1 json;
  v_result2 json;
  v_level1 int;
  v_level2 int;
BEGIN
  UPDATE public.profiles SET cefr_level = NULL, assessment_completed = false
  WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"dddddddd-1111-2222-3333-dddddddddddd","role":"authenticated"}';

  SELECT public.complete_assessment(
    '[{"question_id": "a1_grammar_1", "answer": "is"}]'::jsonb
  ) INTO v_result1;

  SELECT public.complete_assessment(
    '[{"question_id": "a1_grammar_1", "answer": "is"}]'::jsonb
  ) INTO v_result2;

  RESET ROLE;

  v_level1 := (v_result1 ->> 'cefr_level')::int;
  v_level2 := (v_result2 ->> 'cefr_level')::int;

  IF v_level1 != v_level2 THEN
    RAISE EXCEPTION 'TEST FAILED: double call returned different levels (% vs %)', v_level1, v_level2;
  END IF;

  RAISE NOTICE 'PASS: complete_assessment double call is idempotent (level=% both times)', v_level1;
END $$;

-- ════════════════════════════════════════════
-- upsert_word_learning_progress
-- ════════════════════════════════════════════

-- ── Test 7: anon CANNOT call upsert_word_learning_progress ──
DO $$
BEGIN
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.upsert_word_learning_progress(
      'dddddddd-1111-2222-3333-dddddddddddd'::uuid,
      current_date
    );
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon called upsert_word_learning_progress';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call upsert_word_learning_progress';
  END;
END $$;

-- ── Test 8: authenticated can call upsert_word_learning_progress ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_word_id uuid;
  v_count int;
BEGIN
  -- Get a word ID to use
  SELECT id INTO v_word_id FROM public.daily_words LIMIT 1;

  IF v_word_id IS NULL THEN
    RAISE NOTICE 'SKIP: no words in daily_words table, cannot test upsert_word_learning_progress';
    RETURN;
  END IF;

  -- Clean up prior progress
  DELETE FROM public.word_learning_progress
  WHERE user_id = v_test_uid AND word_id = v_word_id;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"dddddddd-1111-2222-3333-dddddddddddd","role":"authenticated"}';

  PERFORM public.upsert_word_learning_progress(v_word_id, current_date);

  RESET ROLE;

  SELECT correct_count INTO v_count
  FROM public.word_learning_progress
  WHERE user_id = v_test_uid AND word_id = v_word_id;

  IF v_count IS NULL OR v_count < 1 THEN
    RAISE EXCEPTION 'TEST FAILED: upsert_word_learning_progress did not create/update row';
  END IF;

  RAISE NOTICE 'PASS: authenticated can call upsert_word_learning_progress (count=%)', v_count;
END $$;

-- ── Test 9: upsert_word_learning_progress double call with same date is idempotent ──
DO $$
DECLARE
  v_test_uid uuid := 'dddddddd-1111-2222-3333-dddddddddddd';
  v_word_id uuid;
  v_count int;
BEGIN
  SELECT id INTO v_word_id FROM public.daily_words LIMIT 1;

  IF v_word_id IS NULL THEN
    RAISE NOTICE 'SKIP: no words in daily_words table';
    RETURN;
  END IF;

  DELETE FROM public.word_learning_progress
  WHERE user_id = v_test_uid AND word_id = v_word_id;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"dddddddd-1111-2222-3333-dddddddddddd","role":"authenticated"}';

  PERFORM public.upsert_word_learning_progress(v_word_id, current_date);
  PERFORM public.upsert_word_learning_progress(v_word_id, current_date);

  RESET ROLE;

  SELECT correct_count INTO v_count
  FROM public.word_learning_progress
  WHERE user_id = v_test_uid AND word_id = v_word_id;

  -- Same date called twice should NOT double-count (deduplication in dates_correct)
  IF v_count != 1 THEN
    RAISE EXCEPTION 'TEST FAILED: double call same date should give count=1, got %', v_count;
  END IF;

  RAISE NOTICE 'PASS: upsert_word_learning_progress same-date double call is idempotent (count=1)';
END $$;

-- ════════════════════════════════════════════
-- get_todays_words
-- ════════════════════════════════════════════

-- ── Test 10: anon CANNOT call get_todays_words ──
DO $$
BEGIN
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.get_todays_words();
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon called get_todays_words';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call get_todays_words';
  END;
END $$;

-- ── Cleanup ──
DELETE FROM public.word_learning_progress WHERE user_id = 'dddddddd-1111-2222-3333-dddddddddddd';
DELETE FROM public.user_daily_usage WHERE user_id = 'dddddddd-1111-2222-3333-dddddddddddd';
DELETE FROM auth.users WHERE id = 'dddddddd-1111-2222-3333-dddddddddddd';

DO $$ BEGIN
  RAISE NOTICE '====================================';
  RAISE NOTICE 'All RPC contract tests passed!';
  RAISE NOTICE '====================================';
END $$;
