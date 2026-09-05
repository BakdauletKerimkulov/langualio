# Binding Rules — Backend Index (Supabase)

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

**Read this file in full** together with `RULES.md`. `→ supabase.md` and `→ edge-functions.md` hold the full patterns — read the relevant one whenever you touch schema, RLS, RPC, or an Edge Function.

Project-specific tables, columns, and function contracts → `ai_docs/`, never here.

---

## Schema

- Every table has `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `created_at timestamptz DEFAULT now()`, `updated_at timestamptz DEFAULT now()` + a `set_updated_at` trigger.
- Timestamps come from Postgres `now()`. Never send `created_at` / `updated_at` from the client.
- `snake_case`, tables plural.
- Every schema change is a migration (`supabase migration new`). Never edit the DB by hand in Studio. Migrations are append-only — never rewrite an applied one. Verify with `supabase db reset` before `db push`.
- Prefer backward-compatible changes: add nullable → backfill → tighten.

## RLS

- `ENABLE ROW LEVEL SECURITY` on **every** table. No policy = no access. Deny by default.
- Never trust client-sent data for prices, scores, quotas, or permissions.
- Server-authoritative columns get no client `UPDATE` policy — route writes through an RPC/Edge Function, or restrict with `REVOKE UPDATE` + `GRANT UPDATE (col, col)`.
- Audit/history tables: `INSERT` policy only.
- No client-side `DELETE` for critical data (orders, payments, progress).
- Every user-facing query is bounded: `.limit(n)` or scoped by `user_id`.
- Index every column used in a policy or a frequent filter.
- Test policies as `anon` / `authenticated` — never as `postgres`, which bypasses RLS.

## RPC

- Every `SECURITY DEFINER` function needs all three: `SET search_path = public`, an `auth.uid() IS NULL` guard, and `REVOKE EXECUTE ... FROM anon, public` + `GRANT ... TO authenticated`.
- Prefer `SECURITY INVOKER` (default) for read-only functions.
- **An RPC body is one transaction.** Any multi-table write that must succeed or fail together belongs in a single RPC — never sequential client or Edge Function awaits.

## Races & idempotency

- Never check-then-write across awaits. In order of preference: atomic conditional `UPDATE ... WHERE quantity >= 1 RETURNING id` (no row = rejected) → `FOR UPDATE` row lock inside an RPC → unique constraint as last defense.
- Every state-changing operation needs a documented strategy: unique constraint + `upsert(onConflict:)` (preferred), deterministic natural key, or a status guard (`WHERE status = 'expected'`, check row count).

## Roles

- Roles live in `auth.users.raw_app_meta_data` (**app_metadata**) — server-writable only. **Never** `user_metadata`: the client edits it freely, so any security decision based on it is broken.
- Check in RLS via the JWT claim: `(auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'`.
- The JWT is a cache — a revoked role stays valid until refresh (~1 h). For instant lockout, additionally check a table. Document that granting requires re-login.
- Role/whitelist tables: RLS enabled with **no client policies at all** — written only by migrations or the service role.
- Admin-only Edge Functions verify the role explicitly after `getUser(token)` and return 403 — the service-role client bypasses RLS, so RLS will not protect you there.
- Client-side `isAdmin` is UX only; enforcement is always RLS/RPC/403.

## Edge Functions → `edge-functions.md`

- Edge Functions are for external APIs, logic that must not ship in the client, and orchestration. Pure DB logic belongs in an RPC.
- Service role key is server-side only, never exposed; always re-verify the JWT (`auth.getUser(token)`) before acting for a user.
- One function per folder, `kebab-case`, verb-first. Past ~200 lines split pure logic into siblings and keep `index.ts` a thin handler. Shared code in `_shared/` the moment a second function exists.
- Secrets and limits read once at module top via `Deno.env.get`; fail fast if missing. Never inline API keys, model IDs, or numeric limits mid-function — hoist to `SCREAMING_SNAKE_CASE` constants. Table names are constants, not scattered literals.
- Handler order, commented and early-returning: CORS → auth (401) → quota (429) → validate input (400) → work → validate external response (502) → persist → respond. Whole body in one try/catch returning a generic 500. Nesting max ~2 levels.
- All responses through one `jsonResponse(body, status)` helper. Structured `{ error }` bodies. Never leak secrets, stack traces, or raw upstream errors — log them server-side with ids and operation.
- External APIs: check `response.ok` before reading the body; never trust AI output (parse in try/catch, validate shape, 502 on failure); pin versions and model IDs as exact strings from the provider docs and smoke-test after any change.
- **Prompt injection:** any user-controlled text interpolated into a prompt is hostile. Cap length, strip control characters, neutralize markdown structure markers. Client-writable rows fed back into prompts (chat history) count as user input — constrain them with an RLS `with check`.
- Quotas are consumed **atomically in the DB** via an RPC ticket, **before** the expensive external call. Quota tables get no client INSERT/UPDATE policies. Decide and comment whether a failed upstream call refunds the ticket.
- Never `any` for untrusted JSON — `Record<string, unknown>` + narrowing.
- Never change table names or response JSON field names without an explicit request — it breaks the client.
- Not done until exercised locally: happy path + at least one failure path.

## Client side

- Repository injects `SupabaseClient`, keeps row → domain mapping in a **pure static function** (testable without a client), never exposes raw rows or `PostgrestException`.
- `SupabaseErrorMapper` maps to the `AppException` hierarchy (`architecture.md` → Error Handling) in `data/`. RLS denials surface as `PostgrestException` — map them, never leak raw Postgres text to the UI.
- The anon key is public by design and safe **only because RLS is on every table**.

---

<!-- digest-of: supabase.md edge-functions.md -->
