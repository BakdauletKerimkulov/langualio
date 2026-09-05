-- ============================================================
-- RLS + RPC tests for atomic quota (Phase 1: R1, R2, R3)
-- Run against local stack after `supabase db reset`:
--   psql "$LOCAL_DB_URL" -f supabase/tests/rls_quota_test.sql
-- ============================================================

-- Helper: create a test user in auth.users and profiles
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
BEGIN
  -- Clean up from previous runs
  DELETE FROM auth.users WHERE id = v_test_uid;

  -- Insert test user into auth.users
  -- The handle_new_user trigger auto-creates a profiles row
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    v_test_uid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test-quota@example.com',
    crypt('testpassword', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nickname":"Test User"}',
    now(),
    now(),
    '', '', '', ''
  );
END $$;

-- ── Test 1: authenticated user CANNOT update user_daily_usage ──
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  v_count int;
BEGIN
  -- Seed a usage row (as postgres, bypassing RLS)
  INSERT INTO public.user_daily_usage (user_id, date, message_count, generation_count)
  VALUES (v_test_uid, current_date, 5, 3)
  ON CONFLICT (user_id, date) DO UPDATE SET message_count = 5, generation_count = 3;

  -- Switch to authenticated role
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","role":"authenticated"}';

  -- Attempt to reset message_count. The client has SELECT only on this table
  -- (20260905150312), so the write is rejected on privilege, before RLS.
  DECLARE
    v_denied boolean := false;
  BEGIN
    BEGIN
      UPDATE public.user_daily_usage
      SET message_count = 0
      WHERE user_id = v_test_uid;
    EXCEPTION WHEN insufficient_privilege THEN
      v_denied := true;
    END;

    RESET ROLE;

    IF NOT v_denied THEN
      RAISE EXCEPTION 'TEST FAILED: authenticated user was allowed to UPDATE user_daily_usage';
    END IF;
  END;

  -- Verify value unchanged
  SELECT message_count INTO v_count
  FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  IF v_count != 5 THEN
    RAISE EXCEPTION 'TEST FAILED: message_count changed to % (expected 5)', v_count;
  END IF;

  RAISE NOTICE 'PASS: authenticated user cannot UPDATE user_daily_usage';
END $$;

-- ── Test 2: authenticated user CANNOT insert into user_daily_usage ──
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  v_count int;
BEGIN
  -- Clean up tomorrow's row if exists
  DELETE FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date + 1;

  -- Switch to authenticated role
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","role":"authenticated"}';

  -- Attempt to insert — should fail (no INSERT policy)
  BEGIN
    INSERT INTO public.user_daily_usage (user_id, date, message_count)
    VALUES (v_test_uid, current_date + 1, 0);

    -- If we get here, the insert succeeded — that's a failure
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: authenticated user was able to INSERT into user_daily_usage';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: no INSERT policy
    RESET ROLE;
    RAISE NOTICE 'PASS: authenticated user cannot INSERT into user_daily_usage';
  END;
END $$;

-- ── Test 3: authenticated user CAN select own usage ──
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  v_count int;
BEGIN
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","role":"authenticated"}';

  SELECT message_count INTO v_count
  FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  RESET ROLE;

  IF v_count IS NULL THEN
    RAISE EXCEPTION 'TEST FAILED: authenticated user cannot SELECT own usage';
  END IF;

  RAISE NOTICE 'PASS: authenticated user can SELECT own usage (message_count=%)', v_count;
END $$;

-- ── Test 4: try_consume_quota returns true up to limit, then false ──
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  v_result boolean;
  v_success_count int := 0;
  v_test_limit int := 5;
BEGIN
  -- Reset usage for clean test
  DELETE FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  -- Call try_consume_quota 7 times with limit 5
  FOR i IN 1..7 LOOP
    SELECT public.try_consume_quota(v_test_uid, 'message', v_test_limit) INTO v_result;
    IF v_result THEN
      v_success_count := v_success_count + 1;
    END IF;
  END LOOP;

  IF v_success_count != v_test_limit THEN
    RAISE EXCEPTION 'TEST FAILED: expected % successes, got %', v_test_limit, v_success_count;
  END IF;

  -- Verify final count equals limit
  DECLARE
    v_final_count int;
  BEGIN
    SELECT message_count INTO v_final_count
    FROM public.user_daily_usage
    WHERE user_id = v_test_uid AND date = current_date;

    IF v_final_count != v_test_limit THEN
      RAISE EXCEPTION 'TEST FAILED: final message_count is % (expected %)', v_final_count, v_test_limit;
    END IF;
  END;

  RAISE NOTICE 'PASS: try_consume_quota returned true exactly % times out of 7 calls', v_test_limit;
END $$;

-- ── Test 5: try_consume_quota works for generation kind ──
DO $$
DECLARE
  v_test_uid uuid := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  v_result boolean;
  v_gen_count int;
BEGIN
  -- Reset usage
  DELETE FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  -- Consume 2 generation quota
  SELECT public.try_consume_quota(v_test_uid, 'generation', 10) INTO v_result;
  IF NOT v_result THEN
    RAISE EXCEPTION 'TEST FAILED: first generation quota should be granted';
  END IF;

  SELECT public.try_consume_quota(v_test_uid, 'generation', 10) INTO v_result;
  IF NOT v_result THEN
    RAISE EXCEPTION 'TEST FAILED: second generation quota should be granted';
  END IF;

  SELECT generation_count INTO v_gen_count
  FROM public.user_daily_usage
  WHERE user_id = v_test_uid AND date = current_date;

  IF v_gen_count != 2 THEN
    RAISE EXCEPTION 'TEST FAILED: generation_count is % (expected 2)', v_gen_count;
  END IF;

  RAISE NOTICE 'PASS: try_consume_quota works for generation kind (count=2)';
END $$;

-- ── Test 6: anon cannot call try_consume_quota ──
DO $$
BEGIN
  SET LOCAL ROLE anon;

  BEGIN
    PERFORM public.try_consume_quota(
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid,
      'message',
      20
    );
    RESET ROLE;
    RAISE EXCEPTION 'TEST FAILED: anon was able to call try_consume_quota';
  EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'PASS: anon cannot call try_consume_quota';
  END;
END $$;

-- ── Cleanup ──
DELETE FROM public.user_daily_usage
WHERE user_id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
DELETE FROM auth.users WHERE id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

DO $$ BEGIN
  RAISE NOTICE '============================';
  RAISE NOTICE 'All quota RLS tests passed!';
  RAISE NOTICE '============================';
END $$;
