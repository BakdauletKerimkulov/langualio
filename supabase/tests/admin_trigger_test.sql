-- ============================================================
-- Admin trigger tests (Phase 4: R14)
-- Verifies handle_admin_role() fires on INSERT (not just UPDATE).
-- Run against local stack after `supabase db reset`:
--   psql "$LOCAL_DB_URL" -f supabase/tests/admin_trigger_test.sql
-- ============================================================

-- ── Test 1: new user with whitelisted email gets admin role on INSERT ──
DO $$
DECLARE
  v_admin_uid uuid := 'aaaaaaaa-1111-2222-3333-aaaaaaaaaaaa';
  v_meta jsonb;
BEGIN
  -- Clean up from previous runs
  DELETE FROM auth.users WHERE id = v_admin_uid;

  -- Insert user with an email that exists in admin_emails
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
    v_admin_uid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'bahaarmanov88@gmail.com',  -- whitelisted in admin_emails
    crypt('testpassword', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nickname":"Admin User"}',
    now(),
    now(),
    '', '', '', ''
  );

  -- Check that the trigger set role = 'admin' in raw_app_meta_data
  SELECT raw_app_meta_data INTO v_meta
  FROM auth.users
  WHERE id = v_admin_uid;

  IF v_meta ->> 'role' != 'admin' THEN
    RAISE EXCEPTION 'TEST FAILED: admin email user did not get role=admin on INSERT (got: %)', v_meta;
  END IF;

  RAISE NOTICE 'PASS: new user with whitelisted email gets admin role on INSERT';
END $$;

-- ── Test 2: new user with non-whitelisted email does NOT get admin role ──
DO $$
DECLARE
  v_normal_uid uuid := 'bbbbbbbb-1111-2222-3333-bbbbbbbbbbbb';
  v_meta jsonb;
BEGIN
  -- Clean up from previous runs
  DELETE FROM auth.users WHERE id = v_normal_uid;

  -- Insert user with a non-admin email
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
    v_normal_uid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'regularuser@example.com',  -- NOT in admin_emails
    crypt('testpassword', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nickname":"Regular User"}',
    now(),
    now(),
    '', '', '', ''
  );

  -- Check that the trigger did NOT set role
  SELECT raw_app_meta_data INTO v_meta
  FROM auth.users
  WHERE id = v_normal_uid;

  IF v_meta ? 'role' THEN
    RAISE EXCEPTION 'TEST FAILED: non-admin user got role key on INSERT (got: %)', v_meta;
  END IF;

  RAISE NOTICE 'PASS: new user with non-whitelisted email does NOT get admin role';
END $$;

-- ── Cleanup ──
DELETE FROM auth.users WHERE id = 'aaaaaaaa-1111-2222-3333-aaaaaaaaaaaa';
DELETE FROM auth.users WHERE id = 'bbbbbbbb-1111-2222-3333-bbbbbbbbbbbb';

DO $$ BEGIN
  RAISE NOTICE '================================';
  RAISE NOTICE 'All admin trigger tests passed!';
  RAISE NOTICE '================================';
END $$;
