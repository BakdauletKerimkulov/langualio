# Plan: AI Chat Audit & Edge Function Readiness

Source: `ai_specs/010-ai-chat-audit-spec.md`
Created: 2026-07-04
Status: in-progress

## Overview
Fix the AI chat feature: replace broken SSE streaming with reliable JSON responses (Phase 1), add input validation and security hardening to the Edge Function, fix daily limit parsing on the client, add `cefr_level` to the system prompt, and remove dead code (`ClaudeApiClient`, `SystemPromptBuilder`). Phase 2 (real streaming) is out of scope for this plan.

**Spec:** `ai_specs/010-ai-chat-audit-spec.md`

## Context
- **Structure:** feature-first (`lib/src/features/chat/{domain,data,application,presentation}`)
- **State management:** Riverpod with `@riverpod` codegen; `ChatNotifier` is auto-dispose with `_mounted` pattern — see `lib/src/features/chat/application/chat_provider.dart:63`
- **Reference implementations:** `ChatNotifier` (custom state notifier pattern from `ai_toolkit/riverpod.md:99-127`); Edge Function at `supabase/functions/chat/index.ts`
- **Testing convention:** mirror `lib/` structure under `test/`; `group()` + `test()`; mock repositories for controller tests — `ai_toolkit/architecture.md:537-580`
- **Lint + test command:** `dart analyze && flutter test`
- **Assumptions / Gaps:**
  - No existing chat tests — all are new
  - `ClaudeApiClient` is not imported anywhere in production code — safe to delete
  - `SystemPromptBuilder` is only referenced by its own file — safe to delete
  - Spec says `profiles` table has `cefr_level` column (set by assessment) — assumed present
  - `name` field in profiles used by Edge Function for system prompt — current code uses `profile?.name`; may need to check if column is `name` or `nickname`

## Plan

### Phase 1 — Edge Function: JSON mode + validation + cefr_level (R1, R3, R4, R5, R6)
**Goal:** Make the Edge Function return a reliable JSON response with env var guards, input validation, context sanitization, and CEFR level in the system prompt.

- [x] `supabase/functions/chat/index.ts` — add env var guards at top: check `CLAUDE_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; return 500 `{ error: "Service not configured" }` if any missing (R6)
- [x] `supabase/functions/chat/index.ts` — add message length validation: reject >10,000 chars with 400 `{ error: "Message too long" }` (R4)
- [x] `supabase/functions/chat/index.ts` — sanitize `context_payload`: truncate to 500 chars, strip control chars (0x00–0x1F except 0x0A/0x09), escape `## ` and `---` delimiters (R5)
- [x] `supabase/functions/chat/index.ts` — add `cefr_level` to `buildSystemPrompt`: read from `profiles` table (already fetched), include as `CEFR Level: {level}`, fall back to "beginner" if null (R3)
- [x] `supabase/functions/chat/index.ts` — switch from SSE streaming to JSON mode: call Claude with `stream: false`, collect `response.content[0].text`, return `{ text, daily_limit, daily_remaining }` as JSON (R1)
- [x] Verify: `flutter analyze && flutter test` passed; `supabase functions serve` _blocked: Deno not installed locally — requires manual QA after deploy_

### Phase 2 — Client: JSON parsing + limit badge fix (R2, R7, R8)
**Goal:** Client correctly parses the new JSON response, daily limit badge updates from response body, dead code removed.

- [ ] TDD: sending a message parses JSON `{ text, daily_limit, daily_remaining }` → state has correct `dailyLimit`, `dailyRemaining`, and assistant message text
- [ ] `lib/src/features/chat/application/chat_provider.dart` — rewrite `sendMessage`: parse response body as JSON (`response.data` → `text`, `daily_limit`, `daily_remaining`); remove `_parseSSEResponse` method and header-based limit parsing (R2)
- [ ] TDD: 429 response sets `isLimitReached = true` with error message; 502 response sets error
- [ ] `lib/src/core/api/claude_api_client.dart` — delete file (R7)
- [ ] `lib/src/features/chat/data/system_prompt_builder.dart` — delete file (R8)
- [ ] Verify: `dart analyze && flutter test`

### Phase 3 — .env.example + final validation (R9)
**Goal:** Environment variable documentation and end-to-end sanity check.

- [ ] `supabase/functions/.env.example` — create with `CLAUDE_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and descriptions (R9)
- [ ] TDD: `ChatState.copyWith` — test `clearError`, `clearStreaming`, field defaults, `isLimitReached` computed getter
- [ ] `ai_docs/PROJECT.md` — remove reference to `ClaudeApiClient` in architecture section (line ~173, ~209)
- [ ] Verify: `dart analyze && flutter test`

## Data layer changes
_None._ Existing tables (`chat_messages`, `user_daily_usage`, `app_config`, `profiles`) are sufficient. No new migrations.

## External integrations
- **Anthropic Claude API** (`claude-sonnet-4-20250514`) — called from Edge Function only. Switching from `stream: true` to `stream: false` for Phase 1. Rate limits: 1000 RPM standard tier. Failure → 502 to client.

## Risks
- **Claude API latency with `stream: false`:** non-streaming may take longer for user-perceived response time (up to 15s for max_tokens=1024). Acceptable for Phase 1; Phase 2 (separate scope) re-adds streaming.
- **`profiles` column name mismatch:** Edge Function uses `profile?.name` but `PROJECT.md` says column is `nickname`. Verify during Phase 1 implementation and use the correct column.

## Out of scope
- Message editing/deletion from UI
- Push notifications for chat
- Changing AI model or max_tokens
- CI/CD for Edge Function deployment
- i18n infrastructure (strings stay hardcoded Russian with `.hardcoded`)
- Chat history storage format changes
- End-to-end encryption
- Phase 2 streaming (P2-R1, P2-R2, P2-R3) — implement after Phase 1 ships
- Nice-to-have items (N1 CORS, N2 rate limiting, N3 improved error messages)
