-- ============================================================
-- Grant table DML to client roles + close the PUBLIC EXECUTE hole
--
-- Why this exists
-- ---------------
-- Schema `public` carries two ALTER DEFAULT PRIVILEGES entries:
--   created by supabase_admin -> anon/authenticated/service_role get arwdDxtm
--   created by postgres       -> anon/authenticated/service_role get only Dxtm
-- Migrations run as `postgres`, so every table created by a migration lands
-- WITHOUT select/insert/update/delete for the client roles. A table privilege
-- is checked before any row-level policy, so those tables answered every client
-- query with `permission denied for table ...` and the RLS policies below them
-- were never reached.
--
-- Grants are therefore made explicit here and must stay explicit: never rely on
-- default privileges for a new table again.
--
-- Scope of each grant is the set of commands the table's existing RLS policies
-- already allow. RLS remains the gate; these grants only let the request reach
-- it. `anon` is granted nothing: no policy targets an unauthenticated user, so
-- it stays denied by default.
-- ============================================================

-- ── 1. Reference data: read-only for signed-in users ──

GRANT SELECT ON public.assessment_questions TO authenticated;
GRANT SELECT ON public.daily_word_sets      TO authenticated;
GRANT SELECT ON public.grammar_items        TO authenticated;

-- ── 2. Own-row data: matches the per-user policies ──

-- "Users can view own profile" / "Users can update own profile".
-- UPDATE stays column-scoped: 20260721175539_assessment_server.sql revoked the
-- table-wide grant and re-granted (nickname, avatar_url) only. Do not widen it.
GRANT SELECT ON public.profiles TO authenticated;

-- "Users can view own usage" only. Quota writes go through try_consume_quota,
-- which is SECURITY DEFINER — see 20260721171503_lock_usage_rls.sql.
GRANT SELECT ON public.user_daily_usage TO authenticated;

GRANT SELECT, INSERT, DELETE         ON public.chat_messages          TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.daily_goals            TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.user_grammar_progress  TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.word_learning_progress TO authenticated;
GRANT SELECT, INSERT                 ON public.word_quiz_attempts     TO authenticated;

-- ── 3. Admin-managed data ──
-- Both tables carry an admin-only write policy plus a read policy for everyone
-- signed in; the policy decides who, the grant only lets the query be attempted.

GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_words TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_config  TO authenticated;

-- `admin_emails` is a whitelist table with no client policies at all. It stays
-- unreachable from the client by design — no grant here on purpose.

-- ── 4. service_role: full DML, used by Edge Functions ──
-- It bypasses RLS by design, but it still needs the table privilege.

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;

-- ── 5. Close the PUBLIC EXECUTE hole on two SECURITY DEFINER functions ──
-- 20260514193920_word_quiz_security.sql revoked EXECUTE from `anon` but not from
-- `public`. Postgres grants EXECUTE to PUBLIC by default, so anon kept reaching
-- both functions through it and only the in-function auth guard stopped them.

REVOKE EXECUTE ON FUNCTION public.get_todays_words()                       FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.upsert_word_learning_progress(uuid, date) FROM anon, public;

GRANT EXECUTE ON FUNCTION public.get_todays_words()                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_word_learning_progress(uuid, date) TO authenticated;
