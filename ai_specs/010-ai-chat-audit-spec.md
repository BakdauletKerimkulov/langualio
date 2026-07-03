# Spec: AI Chat Audit & Edge Function Readiness

Created: 2026-07-03
Status: refined
Refined: 2026-07-04
Source request: Проанализировать фичу чата с ИИ. Найти пробелы, баги и уязвимости. Затем подготовить edge функцию supabase к тому, что мне нужно будет просто вставить ключ и все будет работать

## Goal
Audit the AI chat feature end-to-end: fix bugs preventing chat from working (broken streaming, unparseable headers), close security vulnerabilities (prompt injection, missing input validation), and make the Supabase Edge Function production-ready so deploying requires only setting `CLAUDE_API_KEY`. Phase 1 removes broken streaming in favor of reliable JSON responses. Phase 2 re-adds real streaming via direct HTTP.

## Background

**Stack & conventions:** Flutter + Supabase (Edge Functions in Deno/TypeScript). State management via Riverpod with `@riverpod` codegen. Feature-first architecture with domain/data/application/presentation layers (`ai_toolkit/architecture.md`). Repositories return domain models, never raw maps (`ai_toolkit/architecture.md:79`). No `print()` — use `AppLogger` (`ai_toolkit/code-style.md:253`). All user-visible strings in Russian with `.hardcoded` (`ai_toolkit/code-style.md:268`).

**Project context:** Chat is one of four working backend-integrated features (auth, chat, assessment, onboarding). The Edge Function at `supabase/functions/chat/index.ts` calls Claude API with streaming SSE, but the Flutter client uses `supabase.functions.invoke()` which does NOT support SSE — it buffers the entire response. This means the streaming UI (`streamingText` in `ChatState`) never activates. The response is parsed as a string blob of SSE events. Headers (`X-Daily-Limit`, `X-Daily-Remaining`) are read via `response.data?['_headers']` which is not a real Supabase SDK API — these values are silently `null`. See `ai_docs/PROJECT.md` for full project context.

**Why now:** The chat feature is the core differentiator of the app. It appears to work in development but has several silent failures (limit counter stuck at 20/20, no real streaming, prompt injection surface). Before adding the API key for production, these must be fixed.

## User Flow

### Happy path (Phase 1 — no streaming)
1. User opens `/chat` → cached messages load instantly from SharedPreferences → server fetch updates in background.
2. User types a message → taps send → user bubble appears, typing indicator shows.
3. Edge Function receives message → validates auth, checks daily limit → fetches profile (including `cefr_level`) → builds system prompt → calls Claude (non-streaming) → returns JSON with `{ text, daily_limit, daily_remaining }`.
4. Flutter client parses JSON → hides typing indicator → shows assistant bubble → updates limit badge in AppBar.
5. Both messages are persisted server-side (`chat_messages`) and cached locally.

### Happy path (Phase 2 — streaming, separate scope)
1. Steps 1–2 same as Phase 1.
2. Flutter client sends HTTP POST to `{supabaseUrl}/functions/v1/chat?stream=true` with `Authorization: Bearer {accessToken}` (token from `supabase.auth.currentSession?.accessToken`).
3. Edge Function streams SSE chunks → client reads `StreamedResponse` via `package:http`, updates `streamingText` in state → text appears incrementally in assistant bubble.
4. On stream end → Edge Function emits custom `event: metadata` with `{ daily_limit, daily_remaining }` → full message saved server-side → client persists locally → limit counter updated from metadata event.

### Alternative flows
- If `initialPrompt` is passed via route extra (from grammar/practice screen), message auto-sends on screen init with `context_source` and `context_payload`.
- If user opens chat with no history → suggested prompts are shown instead of empty list.

### Error & recovery flows
- **401 (auth expired):** Show error banner "Сессия истекла. Войди заново." — no retry button (user must re-authenticate).
- **429 (daily limit):** Show limit banner, disable input bar, update badge to `0/N`.
- **502 (Claude API error):** Show error banner with retry button. Retry resends the last user message.
- **Network failure:** Show error banner "Не удалось отправить сообщение. Проверь интернет." with retry.
- **Missing `CLAUDE_API_KEY`:** Edge Function returns 500 with `{ error: "Service not configured" }` (not a crash).

### Edge cases
- **Empty state:** Suggested prompts shown. No typing indicator, no limit banner.
- **First message ever:** `user_daily_usage` row doesn't exist yet — Edge Function upserts correctly (already handled).
- **Very long message (>10k chars):** Edge Function rejects with 400 `{ error: "Message too long" }`.
- **Concurrent sends (double-tap):** Client disables send button while `isLoading` (already handled in UI).
- **Mid-stream exit (Phase 2):** Partial response is lost — acceptable for MVP. Edge Function still saves full response server-side via `finally` block.
- **`cefr_level` is null (assessment not completed):** Edge Function falls back to "beginner" in system prompt. Router guard should prevent this, but defense-in-depth.

## Requirements

### Must Have

- [ ] R1: **Phase 1 — JSON mode.** Edge Function collects full Claude response server-side, returns `{ text, daily_limit, daily_remaining }` as JSON. Client parses this instead of SSE. Verifiable by: sending a message and receiving a JSON response with all three fields.
- [ ] R2: **Fix daily limit parsing.** Client reads `daily_limit` and `daily_remaining` from JSON response body (not headers). Limit badge updates after each message. Verifiable by: sending messages and seeing badge count down.
- [ ] R3: **Add `cefr_level` to system prompt.** Edge Function reads `cefr_level` from `profiles` table and includes it in the system prompt (e.g., "CEFR Level: B1"). Falls back to "beginner" if null (defense-in-depth — router guard should prevent null, but "beginner" gives Claude an actionable signal). Verifiable by: checking Edge Function logs for system prompt content.
- [ ] R4: **Input validation — message length.** Edge Function rejects messages longer than 10,000 characters with 400 status. Verifiable by: sending a >10k char message and getting a 400 response.
- [ ] R5: **Sanitize `context_payload`.** Truncate `context_payload` to 500 characters. Strip ASCII control characters (0x00–0x1F) except newline (0x0A) and tab (0x09). Escape sequences that could be interpreted as prompt section delimiters (e.g., `## `, `---`). Verifiable by: sending a message with a >500 char context_payload and checking it is truncated in the system prompt.
- [ ] R6: **Env var guards.** Edge Function checks `CLAUDE_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` at startup. Returns 500 `{ error: "Service not configured" }` if any is missing. Verifiable by: deploying without `CLAUDE_API_KEY` and getting a 500 JSON response (not a crash).
- [ ] R7: **Remove `ClaudeApiClient`.** Delete `lib/src/core/api/claude_api_client.dart` and all imports. Verifiable by: `dart analyze` passes with no references to `ClaudeApiClient`.
- [ ] R8: **Remove client-side `SystemPromptBuilder`.** Delete `lib/src/features/chat/data/system_prompt_builder.dart` if it is not used by the client (all prompt building happens server-side). Verifiable by: `dart analyze` passes.
- [ ] R9: **Add `.env.example` for Edge Function.** File at `supabase/functions/.env.example` listing all required env vars with descriptions. Verifiable by: file exists with correct variable names.

### Phase 2 — Streaming (separate scope, implement after Phase 1 ships)

Phase 2 replaces Phase 1's JSON response with real SSE streaming. R1's JSON mode becomes obsolete once Phase 2 is complete. Do not implement Phase 2 until Phase 1 is validated in production.

- [ ] P2-R1: **Edge Function streaming mode.** Edge Function accepts query param `?stream=true`. When absent, returns JSON (Phase 1 behavior). When present, streams SSE chunks from Claude. After the last Claude chunk, emits a custom event: `event: metadata\ndata: {"daily_limit": 20, "daily_remaining": 15}\n\n`, then closes the stream.
- [ ] P2-R2: **Client HTTP streaming.** Client sends HTTP POST directly to `{supabaseUrl}/functions/v1/chat?stream=true` with `Authorization: Bearer {token}` (token from `supabase.auth.currentSession?.accessToken`, base URL from `supabase.supabaseUrl`). Reads SSE stream via `package:http` (`Client.send()` with `StreamedResponse`), updates `streamingText` on each `content_block_delta`. Parses `metadata` event for daily limits. Verifiable by: sending a message and seeing text appear incrementally in the assistant bubble.
- [ ] P2-R3: **Graceful fallback.** If streaming HTTP request fails (network error, non-200), fall back to Phase 1 JSON mode automatically. Verifiable by: disabling direct HTTP access and seeing chat still work via JSON.

### Nice to Have

- [ ] N1: **CORS restriction.** Replace `Access-Control-Allow-Origin: *` with a configurable allowed origin (from env var `ALLOWED_ORIGIN`, default `*`). Verifiable by: setting `ALLOWED_ORIGIN` and seeing CORS rejection from other origins.
- [ ] N2: **Request-level rate limiting.** Add a per-user rate limit of max 1 request per 3 seconds (in-memory map with TTL). Prevents rapid-fire spam within the daily limit. Verifiable by: sending 2 messages within 3 seconds and getting 429 on the second.
- [ ] N3: **Improve error messages.** Map Claude API error codes (rate limit, overloaded, invalid key) to specific user-facing messages instead of generic "AI service error". Verifiable by: simulating a Claude rate limit and seeing "AI сервис перегружен. Попробуй через минуту."

### Non-functional

- Performance: Edge Function response (non-streaming) must complete in <15 seconds for typical queries. Claude max_tokens=1024 limits response size.
- Accessibility: Chat input bar must have semantic label. Message bubbles should have role-based semantics for screen readers.
- i18n: All new user-facing strings use `.hardcoded` extension. Strings are in Russian.

## Technical Constraints

**Files to create:**
- `supabase/functions/.env.example` — environment variable template with descriptions

**Files to modify:**
- `supabase/functions/chat/index.ts` — Phase 1: return JSON instead of SSE stream; add env var guards, input validation, context sanitization, cefr_level in prompt
- `lib/src/features/chat/application/chat_provider.dart` — Phase 1: parse JSON response body for text + limits
- `lib/src/features/chat/presentation/chat_screen.dart` — verify limit badge works with JSON-sourced data (already implemented, just needs working data)

**Files to modify (Phase 2 only — separate scope):**
- `supabase/functions/chat/index.ts` — add `?stream=true` query param support, custom `metadata` SSE event
- `lib/src/features/chat/application/chat_provider.dart` — add HTTP-based streaming with `streamingText` updates
- `lib/src/features/chat/data/chat_repository.dart` — add Edge Function base URL helper (`supabase.supabaseUrl + '/functions/v1/chat'`) and streaming HTTP method
- `lib/src/features/chat/presentation/chat_screen.dart` — verify streaming UI works with `streamingText` state

**Files to delete:**
- `lib/src/core/api/claude_api_client.dart` — dead code, API key should never be on client
- `lib/src/features/chat/data/system_prompt_builder.dart` — duplicate of server-side logic (verify no client usage first)

**Patterns to follow (with citations):**
- Follow the repository pattern in `lib/src/features/chat/data/chat_repository.dart` for any new data access.
- Follow the controller pattern in `lib/src/features/chat/application/chat_provider.dart` (ChatNotifier with `_mounted` check) per `ai_toolkit/riverpod.md:70-96`.
- Edge Function follows the thin-orchestrator principle (validate → fetch → compute → respond) from `ai_toolkit/firebase.md` § Cloud Functions Structure, adapted for Deno/Supabase patterns (`Deno.serve()`, `supabaseClient.auth.getUser()`, Supabase client queries).

**Anti-patterns / avoid:**
- Do not add new Flutter dependencies for HTTP streaming — the `http` package (`^1.2.2`) is already in `pubspec.yaml`.
- Do not expose `CLAUDE_API_KEY` or any secret on the client side. All Claude calls go through Edge Function.
- Do not use `print()` in Dart — use `log()` from `core/utils/logger.dart` (`ai_toolkit/code-style.md:253`).
- Do not use `withOpacity()` — use `withValues(alpha:)` (`ai_toolkit/flutter.md:29`).

**Data layer changes:** None. Existing tables (`chat_messages`, `user_daily_usage`, `app_config`, `profiles`) are sufficient. No new migrations needed.

**External integrations:**
- Anthropic Claude API (`claude-sonnet-4-20250514`) — called from Edge Function only. Rate limits: 1000 RPM on standard tier. Failure mode: 429/529 → retry with backoff or return 502 to client. Invalid API key → 401 from Claude → return 502 to client.

## Out of Scope

- **NOT** adding message editing or deletion from UI — not needed for MVP.
- **NOT** adding push notifications for chat — separate feature.
- **NOT** changing the AI model or max_tokens — current config is adequate.
- **NOT** setting up CI/CD for Edge Function deployment — manual `supabase functions deploy chat` is fine.
- **NOT** adding i18n infrastructure — strings stay hardcoded in Russian with `.hardcoded`.
- **NOT** migrating chat history to a different storage format — current schema is fine.
- **NOT** adding end-to-end encryption for chat messages — out of scope for language learning app.

## Validation

**Automated tests:**
- Unit: Test JSON response parsing logic (Phase 1) — `test/src/features/chat/application/chat_provider_test.dart`
- Unit: Test `ChatState.copyWith` — edge cases for `clearError`, `clearStreaming`
- Unit: Test message length validation logic (if extracted to domain layer)
- Unit (Phase 2): Test SSE stream parser (new implementation, not the legacy `_parseSSEResponse` which parses buffered Supabase responses and is removed in Phase 1)

**Manual QA scenarios:**
1. Given fresh deploy with `CLAUDE_API_KEY` set, when user sends "Hello", then assistant responds with English-learning guidance in <15s.
2. Given a user who has sent 19 messages today, when they send the 20th, then badge shows `0/20` and input is disabled after response.
3. Given a user who has sent 20 messages, when they open chat, then limit banner is visible and input is disabled.
4. Given Edge Function deployed WITHOUT `CLAUDE_API_KEY`, when user sends a message, then they see "Ошибка AI-сервиса" (not a crash/timeout).
5. Given a message >10,000 characters, when sent, then user sees an error (not a timeout or crash).
6. Given a user with `cefr_level = 'B1'` in profiles, when they chat, then Claude adapts responses to B1 level (check Edge Function logs for system prompt).
7. (Phase 2) Given streaming enabled, when user sends a message, then text appears word-by-word in the assistant bubble.

**Expected behavior under edge conditions:**
- Offline → Error banner "Не удалось отправить. Проверь интернет." with retry button. Previous messages remain visible from cache.
- Backend error (502) → Error banner with retry. Last user message stays in chat for context.
- Empty data (no chat history) → Suggested prompts screen. No crash.

## Definition of Done

- [ ] All Must Have requirements pass automated tests
- [ ] All Manual QA scenarios pass on Android and iOS
- [ ] `dart analyze` reports no new warnings
- [ ] Edge Function deploys successfully with `supabase functions deploy chat`
- [ ] `.env.example` documents all required environment variables
- [ ] `ClaudeApiClient` and `SystemPromptBuilder` are removed (if unused)
- [ ] No new lint warnings; matches `ai_toolkit/` style guide
- [ ] Spec file linked in the PR description
