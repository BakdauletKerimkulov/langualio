-- ============================================================
-- Lock user_daily_usage: remove client INSERT/UPDATE policies (R3)
-- Quota is now managed atomically via try_consume_quota RPC
-- (service role, bypasses RLS). Client keeps SELECT to see remaining.
-- ============================================================

-- Drop client INSERT policy
DROP POLICY IF EXISTS "Users can insert own usage" ON public.user_daily_usage;

-- Drop client UPDATE policy
DROP POLICY IF EXISTS "Users can update own usage" ON public.user_daily_usage;

-- SELECT policy ("Users can view own usage") remains — client reads remaining quota.
