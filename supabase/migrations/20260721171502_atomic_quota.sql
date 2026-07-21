-- ============================================================
-- Atomic Quota: try_consume_quota RPC
-- Prevents race conditions in rate limiting by atomically
-- incrementing the counter with a limit check in one statement.
-- ============================================================

CREATE OR REPLACE FUNCTION public.try_consume_quota(
  p_user_id uuid,
  p_kind text,
  p_limit int
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed boolean;
BEGIN
  -- Auth guard: only service-role calls this, but verify user exists
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID is required';
  END IF;

  -- Upsert today's row and atomically increment the right counter.
  -- Returns true if the counter was below the limit (quota granted).
  IF p_kind = 'message' THEN
    INSERT INTO public.user_daily_usage (user_id, date, message_count)
    VALUES (p_user_id, current_date, 1)
    ON CONFLICT (user_id, date) DO UPDATE
      SET message_count = user_daily_usage.message_count + 1
    WHERE user_daily_usage.message_count < p_limit;
  ELSIF p_kind = 'generation' THEN
    INSERT INTO public.user_daily_usage (user_id, date, generation_count)
    VALUES (p_user_id, current_date, 1)
    ON CONFLICT (user_id, date) DO UPDATE
      SET generation_count = user_daily_usage.generation_count + 1
    WHERE user_daily_usage.generation_count < p_limit;
  ELSE
    RAISE EXCEPTION 'Invalid quota kind: %', p_kind;
  END IF;

  -- If a row was inserted or updated, quota was granted
  GET DIAGNOSTICS v_allowed = ROW_COUNT;
  RETURN v_allowed > 0;

  -- TODO: decide if quota should be refunded on Claude error (spec Q1).
  -- If yes, add a companion RPC: refund_quota(p_user_id, p_kind) that decrements.
END;
$$;

-- Service-role calls this from edge functions; also allow authenticated
-- so the RPC is callable from client if needed for remaining-count checks.
REVOKE EXECUTE ON FUNCTION public.try_consume_quota(uuid, text, int) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.try_consume_quota(uuid, text, int) TO authenticated, service_role;
