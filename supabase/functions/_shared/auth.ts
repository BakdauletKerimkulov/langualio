import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "./response.ts";
import { requireEnv } from "./env.ts";

export interface AuthResult {
  user: User;
  supabase: SupabaseClient;
}

/**
 * Verify the Authorization header and return the authenticated user
 * and a service-role Supabase client.
 *
 * Returns an AuthResult on success, or a Response (401) on failure.
 */
export async function verifyAuth(
  req: Request
): Promise<AuthResult | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  return { user, supabase };
}
