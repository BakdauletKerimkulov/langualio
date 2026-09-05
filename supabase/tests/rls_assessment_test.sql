-- ============================================================
-- RLS tests for server-side assessment (Phase 2: R4)
-- Run against local stack after `supabase db reset`:
--   psql "$LOCAL_DB_URL" -f supabase/tests/rls_assessment_test.sql
-- ============================================================

-- Helper: create a test user
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
BEGIN
  DELETE FROM auth.users WHERE id = v_test_uid;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    v_test_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'test-assessment@example.com',
    crypt('testpassword', gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}',
    '{"nickname":"Assessment Tester"}', now(), now(),
    '', '', '', ''
  );
END $$;

-- ── Test 1: authenticated user CANNOT update cefr_level ──
-- 20260721175539_assessment_server.sql revoked the table-wide UPDATE and re-granted
-- (nickname, avatar_url) only. A column-level REVOKE makes Postgres raise
-- insufficient_privilege — it does not silently drop the column from the UPDATE.
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT cefr_level INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  BEGIN
    UPDATE public.profiles SET cefr_level = 5 WHERE id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE cefr_level';
  END IF;

  SELECT cefr_level INTO v_after FROM public.profiles WHERE id = v_test_uid;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: cefr_level changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE cefr_level';
END $$;

-- ── Test 2: authenticated user CANNOT update assessment_completed ──
-- 20260721175539_assessment_server.sql revoked the table-wide UPDATE and re-granted
-- (nickname, avatar_url) only. A column-level REVOKE makes Postgres raise
-- insufficient_privilege — it does not silently drop the column from the UPDATE.
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_orig boolean;
  v_after boolean;
  v_denied boolean := false;
BEGIN
  SELECT assessment_completed INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  BEGIN
    UPDATE public.profiles SET assessment_completed = true WHERE id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE assessment_completed';
  END IF;

  SELECT assessment_completed INTO v_after FROM public.profiles WHERE id = v_test_uid;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: assessment_completed changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE assessment_completed';
END $$;

-- ── Test 3: authenticated user CAN update nickname (allowed column) ──
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_count int;
BEGIN
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  UPDATE public.profiles
  SET nickname = 'Updated Name'
  WHERE id = v_test_uid;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RESET ROLE;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user cannot update nickname';
  END IF;

  RAISE NOTICE 'PASS: authenticated user can UPDATE nickname';
END $$;

-- ── Test 4: authenticated user CAN select own profile ──
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_nickname text;
BEGIN
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  SELECT nickname INTO v_nickname
  FROM public.profiles
  WHERE id = v_test_uid;

  RESET ROLE;

  IF v_nickname IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user cannot SELECT own profile';
  END IF;

  RAISE NOTICE 'PASS: authenticated user can SELECT own profile (nickname=%)', v_nickname;
END $$;

-- ── Test 5: complete_assessment RPC returns correct level for all-correct answers ──
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_result json;
  v_level int;
  v_correct int;
BEGIN
  -- Set auth context for RPC (SECURITY DEFINER uses auth.uid())
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  -- All correct answers
  SELECT public.complete_assessment(
    '[
      {"question_id": "a1_grammar_1", "answer": "is"},
      {"question_id": "a1_reading_1", "answer": "A coffee"},
      {"question_id": "a2_grammar_1", "answer": "went"},
      {"question_id": "a2_listening_1", "answer": "To the shop"},
      {"question_id": "a2_reading_1", "answer": "3 PM"},
      {"question_id": "b1_grammar_1", "answer": "had"},
      {"question_id": "b1_reading_1", "answer": "Better job opportunities"},
      {"question_id": "b1_listening_1", "answer": "take"},
      {"question_id": "b2_grammar_1", "answer": "will have worked"},
      {"question_id": "b2_reading_1", "answer": "It increases productivity but may harm team culture"},
      {"question_id": "b2_listening_1", "answer": "Consistency matters more than intensity"},
      {"question_id": "c1_grammar_1", "answer": "would have left"}
    ]'::jsonb
  ) INTO v_result;

  RESET ROLE;

  v_level := (v_result ->> 'cefr_level')::int;
  v_correct := (v_result ->> 'correct_answers')::int;

  -- All correct should give C1 (level 5)
  IF v_level != 5 THEN
    RAISE EXCEPTION 'TEST FAILED: all correct answers should give C1 (5), got %', v_level;
  END IF;

  IF v_correct != 12 THEN
    RAISE EXCEPTION 'TEST FAILED: expected 12 correct, got %', v_correct;
  END IF;

  -- Verify profile was updated
  DECLARE
    v_db_level int;
    v_db_completed bool;
  BEGIN
    SELECT cefr_level, assessment_completed INTO v_db_level, v_db_completed
    FROM public.profiles WHERE id = v_test_uid;

    IF v_db_level != 5 OR NOT v_db_completed THEN
      RAISE EXCEPTION 'TEST FAILED: profile not updated (level=%, completed=%)', v_db_level, v_db_completed;
    END IF;
  END;

  RAISE NOTICE 'PASS: complete_assessment all correct → C1, 12/12, profile updated';
END $$;

-- ── Test 6: complete_assessment with all wrong answers → A1 ──
DO $$
DECLARE
  v_test_uid uuid := 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
  v_result json;
  v_level int;
BEGIN
  -- Reset profile first
  UPDATE public.profiles SET cefr_level = NULL, assessment_completed = false
  WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff","role":"authenticated"}';

  SELECT public.complete_assessment(
    '[
      {"question_id": "a1_grammar_1", "answer": "wrong"},
      {"question_id": "a1_reading_1", "answer": "wrong"},
      {"question_id": "a2_grammar_1", "answer": "wrong"},
      {"question_id": "a2_listening_1", "answer": "wrong"},
      {"question_id": "a2_reading_1", "answer": "wrong"},
      {"question_id": "b1_grammar_1", "answer": "wrong"},
      {"question_id": "b1_reading_1", "answer": "wrong"},
      {"question_id": "b1_listening_1", "answer": "wrong"},
      {"question_id": "b2_grammar_1", "answer": "wrong"},
      {"question_id": "b2_reading_1", "answer": "wrong"},
      {"question_id": "b2_listening_1", "answer": "wrong"},
      {"question_id": "c1_grammar_1", "answer": "wrong"}
    ]'::jsonb
  ) INTO v_result;

  RESET ROLE;

  v_level := (v_result ->> 'cefr_level')::int;

  IF v_level != 1 THEN
    RAISE EXCEPTION 'TEST FAILED: all wrong answers should give A1 (1), got %', v_level;
  END IF;

  RAISE NOTICE 'PASS: complete_assessment all wrong → A1';
END $$;

-- ── Test 7: anon cannot call complete_assessment ──
DO $$
BEGIN
  SET LOCAL ROLE anon;

  BEGIN
    PERFORM public.complete_assessment('[]'::jsonb);
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon was able to call complete_assessment';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call complete_assessment';
  END;
END $$;

-- ── Cleanup ──
DELETE FROM auth.users WHERE id = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';

DO $$ BEGIN
  RAISE NOTICE '=====================================';
  RAISE NOTICE 'All assessment RLS tests passed!';
  RAISE NOTICE '=====================================';
END $$;
