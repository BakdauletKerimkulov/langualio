-- ============================================================
-- Add BEFORE INSERT trigger for handle_admin_role()
-- Previously only BEFORE UPDATE existed, so new signups with
-- whitelisted emails did not get admin role until next profile update.
--
-- NOTE: JWT cache lag (~1 hour)
-- Supabase caches JWTs until they expire (default ~1h).
-- After a new admin user signs up, their JWT won't contain
-- app_metadata.role = 'admin' until the next token refresh.
-- The user must sign out and back in (or wait for token expiry)
-- before admin privileges take effect in Edge Functions.
-- ============================================================

CREATE TRIGGER on_auth_user_inserted
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_role();
