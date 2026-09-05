-- ============================================================
-- Negative RLS tests for server-authoritative fields (Phase 7: R17)
-- Verifies that authenticated users CANNOT write fields controlled
-- by RPCs and service-role logic.
-- Run against local stack after `supabase db reset`:
--   psql "$LOCAL_DB_URL" -f supabase/tests/rls_server_authoritative_test.sql
-- ============================================================

-- Helper: create a test user
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
BEGIN
  DELETE FROM auth.users WHERE id = v_test_uid;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    v_test_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'test-server-auth@example.com',
    crypt('testpassword', gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}',
    '{"nickname":"Server Auth Tester"}', now(), now(),
    '', '', '', ''
  );
END $$;

-- ── Test 1: authenticated user CANNOT update cefr_level ──
-- Column-level REVOKE raises insufficient_privilege; it does not silently drop
-- the column from the UPDATE. Assert both: the write is rejected AND the stored
-- value is untouched.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT cefr_level INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

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

-- ── Test 2: authenticated user CANNOT update current_xp ──
-- Column-level REVOKE raises insufficient_privilege; it does not silently drop
-- the column from the UPDATE. Assert both: the write is rejected AND the stored
-- value is untouched.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT current_xp INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

  BEGIN
    UPDATE public.profiles SET current_xp = 99999 WHERE id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE current_xp';
  END IF;

  SELECT current_xp INTO v_after FROM public.profiles WHERE id = v_test_uid;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: current_xp changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE current_xp';
END $$;

-- ── Test 3: authenticated user CANNOT update level ──
-- Column-level REVOKE raises insufficient_privilege; it does not silently drop
-- the column from the UPDATE. Assert both: the write is rejected AND the stored
-- value is untouched.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT level INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

  BEGIN
    UPDATE public.profiles SET level = 100 WHERE id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE level';
  END IF;

  SELECT level INTO v_after FROM public.profiles WHERE id = v_test_uid;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: level changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE level';
END $$;

-- ── Test 4: authenticated user CANNOT update streak_days ──
-- Column-level REVOKE raises insufficient_privilege; it does not silently drop
-- the column from the UPDATE. Assert both: the write is rejected AND the stored
-- value is untouched.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT streak_days INTO v_orig FROM public.profiles WHERE id = v_test_uid;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

  BEGIN
    UPDATE public.profiles SET streak_days = 365 WHERE id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE streak_days';
  END IF;

  SELECT streak_days INTO v_after FROM public.profiles WHERE id = v_test_uid;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: streak_days changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE streak_days';
END $$;

-- ── Test 5: authenticated user CANNOT update message_count (user_daily_usage) ──
-- 20260721171503_lock_usage_rls.sql dropped the client INSERT/UPDATE policies and
-- 20260905150312 grants SELECT only, so the write is rejected on privilege.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  -- Seed a usage row as postgres (bypasses RLS)
  INSERT INTO public.user_daily_usage (user_id, date, message_count, generation_count)
  VALUES (v_test_uid, current_date, 5, 2)
  ON CONFLICT (user_id, date) DO UPDATE SET message_count = 5, generation_count = 2;

  SELECT message_count INTO v_orig
  FROM public.user_daily_usage WHERE user_id = v_test_uid AND date = current_date;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

  BEGIN
    UPDATE public.user_daily_usage SET message_count = 0 WHERE user_id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE message_count';
  END IF;

  SELECT message_count INTO v_after
  FROM public.user_daily_usage WHERE user_id = v_test_uid AND date = current_date;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: message_count changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE message_count';
END $$;

-- ── Test 6: authenticated user CANNOT update generation_count (user_daily_usage) ──
-- 20260721171503_lock_usage_rls.sql dropped the client INSERT/UPDATE policies and
-- 20260905150312 grants SELECT only, so the write is rejected on privilege.
DO $$
DECLARE
  v_test_uid uuid := 'cccccccc-1111-2222-3333-cccccccccccc';
  v_orig int;
  v_after int;
  v_denied boolean := false;
BEGIN
  SELECT generation_count INTO v_orig
  FROM public.user_daily_usage WHERE user_id = v_test_uid AND date = current_date;

  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"cccccccc-1111-2222-3333-cccccccccccc","role":"authenticated"}';

  BEGIN
    UPDATE public.user_daily_usage SET generation_count = 0 WHERE user_id = v_test_uid;
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;

  RESET ROLE;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE generation_count';
  END IF;

  SELECT generation_count INTO v_after
  FROM public.user_daily_usage WHERE user_id = v_test_uid AND date = current_date;
  IF v_after IS DISTINCT FROM v_orig THEN
    RAISE EXCEPTION 'TEST FAILED: generation_count changed from % to %', v_orig, v_after;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE generation_count';
END $$;

-- ── Cleanup ──
DELETE FROM public.user_daily_usage WHERE user_id = 'cccccccc-1111-2222-3333-cccccccccccc';
DELETE FROM auth.users WHERE id = 'cccccccc-1111-2222-3333-cccccccccccc';

DO $$ BEGIN
  RAISE NOTICE '================================================';
  RAISE NOTICE 'All server-authoritative field tests passed!';
  RAISE NOTICE '================================================';
END $$;
