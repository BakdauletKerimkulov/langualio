# TypeScript Backend Functions (Supabase Edge Functions)

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

Rules for writing `.ts` backend code in `supabase/functions/`. Patterns adapted from proven Firebase Functions codebases, applied to the Deno / Supabase Edge runtime.

---

## Structure & Naming

- One function per folder: `supabase/functions/{function-name}/index.ts`.
- Folder names: `kebab-case`, verb-first, describing what the function does (`generate-word-entry`, `chat`).
- `index.ts` is the entrypoint. If the file grows beyond ~200 lines, split pure logic into sibling modules (`prompt.ts`, `validation.ts`, `db.ts`) and keep `index.ts` as the thin handler that wires them together.
- Shared code between functions goes in `supabase/functions/_shared/` and is imported relatively.
- Functions: `camelCase`, named for what they do (`jsonResponse`, `calculateCartTotal`, `lookupUserByCustomerId`). Handlers exported as `async function`; small helpers may be `const` arrow functions.
- Constants: `SCREAMING_SNAKE_CASE` at the top of the file (`CLAUDE_MODEL`, `DAILY_GENERATION_LIMIT`, `MAX_TOKENS`).

## Configuration & Secrets

- All secrets and env vars read once at module top via `Deno.env.get(...)`, never inline in handler code.
- Never hardcode API keys, model names as magic strings mid-function, or numeric limits — hoist them to named constants.
- Fail fast if a required secret is missing: check and throw/return 500 before doing any work.

## Paths & Table Names

- Do not scatter table/collection names as string literals through the code. Define them once as constants or small helper functions at the top of the file:

```ts
const USER_DAILY_USAGE_TABLE = "user_daily_usage";
// or, for parameterized paths (Firebase-style pattern):
const userOrdersPath = (uid: string) => `users/${uid}/orders`;
```

- Never change table names or response JSON field names without an explicit request (breaking change for the client).

## Handler Flow

Follow a strict, numbered order inside the handler; comment each step:

1. CORS preflight (`OPTIONS`) — return early.
2. Auth — verify the JWT via `supabase.auth.getUser(token)`; return 401 early.
3. Rate limits / quotas — return 429 early.
4. Parse & validate input — return 400 early with a specific message.
5. Core work (DB reads, external API calls).
6. Validate external responses before trusting them (check shape, parse JSON in try/catch).
7. Persist side effects (counters, records).
8. Return the response.

Rules:

- **Early returns** for every failure branch; no `else`-pyramids, nesting max ~2 levels.
- Guard clauses check `undefined`/`null` explicitly (`if (doc === undefined) return`), mirroring the Firestore snapshot pattern.
- The entire handler body is wrapped in one `try/catch` that returns a generic 500 — no unhandled rejections.

## Responses & Errors

- All responses go through a single `jsonResponse(body, status)` helper — consistent headers (CORS, `Content-Type`) in one place.
- Correct status codes: 400 invalid input, 401 unauthorized, 429 rate limit, 502 upstream/AI failure, 500 unexpected.
- Error bodies are structured JSON: `{ error: "message" }`, optionally with machine-usable fields (`remaining`, `limit`).
- Never leak secrets, stack traces, or raw upstream errors to the client; log them server-side instead.
- Never swallow exceptions: log with context (ids, user id, operation) then rethrow or return an error response:

```ts
console.error(`Could not fulfill order for uid: ${uid}, paymentId: ${paymentId}`, error);
```

- Use `console.warn` for suspicious-but-recoverable states (e.g., amount mismatch), `console.error` for failures.

## External APIs (Claude, etc.)

- Check `response.ok` before reading the body; on failure log status + body text, return 502.
- Never trust AI output: parse in `try/catch`, validate required fields/shape explicitly, return 502 with a clear error when validation fails.
- Pin API versions explicitly (`anthropic-version` header, versioned model IDs). Model IDs are exact strings from the provider's docs — a plausible-looking but invalid ID fails every request at runtime; verify against documentation, keep it in one constant per function, and smoke-test after any change.
- **Prompt injection**: any user-controlled text interpolated into a prompt (messages, context payloads, word inputs) is hostile input. Sanitize before interpolation: cap length, strip control characters, neutralize markdown structure markers (`## `, `---`) that could impersonate system sections. Client-writable DB rows fed back into prompts (e.g., chat history) count as user input too — constrain what clients can write there (RLS `with check` on `role`).

## Rate Limiting & Quotas

- Read-count-then-write across awaits is a race: two parallel requests read the same counter and both pass. Consume quota **atomically in the DB** — an RPC "ticket" (`insert ... on conflict do update set n = n + 1 where n < limit`; row returned = allowed) called **before** the expensive external call.
- Consuming before the paid call also means a crash afterwards can't hand out free usage; decide explicitly (and comment) whether a failed upstream call refunds the ticket.
- Quota tables must have no client INSERT/UPDATE policies — otherwise users reset their own limits via the REST API.
- Functions gated to a role (admin-only generation, etc.) check the role from `app_metadata` right after auth and return 403 — see `supabase.md` → Roles & Admin.

## Shared Code (`_shared/`)

The moment a second function exists, duplicated `jsonResponse`, CORS headers, auth verification, env guards, and quota helpers move to `supabase/functions/_shared/` and are imported relatively. Duplicated copies drift (one function crashes on missing env while another returns a clean 500) — identical concerns must have identical code.

## Data Integrity

- Multi-write operations that must succeed or fail together use a transaction / RPC (Postgres function), not sequential awaits.
- Use `upsert` with explicit `onConflict` for counters and idempotent writes.
- Verify money/quantity invariants server-side (e.g., payment amount vs computed total) — the client is never the source of truth.

## Types

- Type external event/request payloads explicitly; use `Record<string, unknown>` + narrowing for untrusted JSON, never `any`.
- Small local types/interfaces per function file; shared types in `_shared/types.ts`.

## Deploy & Verify

- Local check: `supabase functions serve` + a curl request per changed function.
- Deploy only the changed function: `supabase functions deploy <function-name>`.
- A change is not done until the function has been exercised locally (happy path + at least one failure path: bad auth, bad input).
