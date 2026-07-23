/**
 * Read an environment variable or throw immediately.
 * Fail-fast ensures consistent 500 instead of undefined behavior.
 */
export function requireEnv(key: string): string {
  const value = Deno.env.get(key);
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}
