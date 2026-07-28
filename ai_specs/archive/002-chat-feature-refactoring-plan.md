# Plan: Chat Feature Refactoring

Source: ai_specs/002-chat-feature-refactoring-spec.md
Created: 2026-05-17

## Overview
Refactor the chat client to load history from Supabase `chat_messages` table instead of SharedPreferences-only, add cursor-based pagination, remove mock fallbacks, and implement server-side 48h message filtering. The repository becomes the bridge between Supabase (primary) and SharedPreferences (cache/offline fallback), while the Notifier stays synchronous to avoid widget-level changes.

## Stages

### Stage 1: Database Migration
**Goal:** Add DELETE RLS policy and performance index so the client can delete messages and paginate efficiently.
**Files to create/modify:**
- `supabase/migrations/{timestamp}_add_chat_delete_policy_and_index.sql` — new migration file

**Steps:**
- [x] Run `supabase migration new add_chat_delete_policy_and_index`
- [x] Add DELETE policy: `create policy "Users can delete own messages" on public.chat_messages for delete using (auth.uid() = user_id)`
- [x] Add index: `create index idx_chat_messages_user_created on public.chat_messages(user_id, created_at desc)`
- [ ] Verify with `supabase db reset` locally (requires Docker)

**Verification:** `supabase db reset` succeeds without errors. Confirm policy exists via `\dp chat_messages` in psql.

---

### Stage 2: Domain Model Update
**Goal:** Extend `ChatMessage` with optional `id` field to support server-synced messages.
**Files to create/modify:**
- `lib/src/features/chat/domain/chat_message.dart` — add `id` field

**Steps:**
- [x] Add `final String? id;` field to `ChatMessage`
- [x] Update constructor: `this.id` as optional named parameter
- [x] Ensure existing code that creates `ChatMessage` still compiles (id defaults to null)

**Verification:** `flutter analyze` passes. Existing chat functionality unchanged (id is null for all current messages).

---

### Stage 3: Repository Rewrite
**Goal:** Rewrite `ChatRepository` to fetch from Supabase with pagination and 48h filter, cache to SharedPreferences, fallback to cache on error.
**Files to create/modify:**
- `lib/src/features/chat/data/chat_repository.dart` — full rewrite

**Steps:**
- [x] Change constructor to accept both `LocalStorage` and `SupabaseClient`
- [x] Change provider annotation to `@Riverpod(keepAlive: true)`, inject both deps
- [x] Implement `List<ChatMessage> loadCachedMessages()` — sync load from SharedPreferences (same as current `loadMessages()`)
- [x] Implement `Future<List<ChatMessage>> fetchMessages({int limit = 20, DateTime? before})` — query `chat_messages` with `.select()`, filter `created_at > now() - 48h`, order by `created_at desc`, limit, cursor via `before` parameter. On success, update cache. On network error, return `loadCachedMessages()`
- [x] Implement `Future<void> deleteAllMessages()` — call `.delete()` on `chat_messages` (RLS handles user_id filter), on success clear SharedPreferences, on error throw
- [x] Update `saveMessages()` to handle the new `id` field in serialization
- [x] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `.g.dart`

**Verification:** `flutter analyze` passes. Unit-testable: repository methods can be called with mock Supabase client.

---

### Stage 4: Controller Refactoring
**Goal:** Update `ChatNotifier` to use new repository methods, add pagination state, remove mock fallback.
**Files to create/modify:**
- `lib/src/features/chat/application/chat_provider.dart` — refactor

**Steps:**
- [x] Extend `ChatState` with `hasMore` (default true) and `isLoadingMore` (default false) fields, update `copyWith`
- [x] Rewrite `build()`: load cache sync via `_repository.loadCachedMessages()`, then fire-and-forget `_refreshFromServer()` that fetches from Supabase and replaces state
- [x] Implement `_refreshFromServer()`: call `fetchMessages()`, update `state.messages`, set `hasMore` based on result count < 20
- [x] Implement `loadMore()`: if `!hasMore || isLoadingMore` return early. Set `isLoadingMore = true`, call `fetchMessages(before: oldest message timestamp)`, prepend results to messages, set `hasMore`, set `isLoadingMore = false`
- [x] Remove `_mockResponse()` method entirely
- [x] In `sendMessage()` catch block: remove the `FunctionException`/`Failed host lookup` → mock fallback. Always show error state with user-friendly message
- [x] Update `clearHistory()`: call `_repository.deleteAllMessages()`, on success reset state, on error set `state.error`
- [x] After sending a message successfully, append both user + assistant messages to local cache via `_repository.saveMessages()`
- [x] Run `dart run build_runner build --delete-conflicting-outputs`

**Verification:** `flutter analyze` passes. Mock responses are gone. Sending a message with no server shows error, not fake response.

---

### Stage 5: Pagination UI
**Goal:** Add scroll-triggered pagination in the chat screen.
**Files to create/modify:**
- `lib/src/features/chat/presentation/chat_screen.dart` — add scroll listener and loading indicator

**Steps:**
- [x] Add scroll listener in `initState()`: on scroll, check if `pixels <= minScrollExtent + 200`
- [x] When threshold hit and `!isLoadingMore && hasMore`: call `ref.read(chatNotifierProvider.notifier).loadMore()`
- [x] Add loading indicator widget at top of ListView when `state.isLoadingMore` is true
- [x] Ensure scroll position is preserved when new messages are prepended (maintain offset)
- [x] Remove scroll listener in `dispose()`

**Verification:** Run app, send several messages to build history. Scroll up — older messages load. When no more messages, indicator disappears and no more fetches fire.

---

### Stage 6: Edge Cases & Polish
**Goal:** Handle all specified edge cases and verify end-to-end behavior.
**Files to create/modify:**
- `lib/src/features/chat/application/chat_provider.dart` — error handling refinements
- `lib/src/features/chat/presentation/chat_screen.dart` — error UI adjustments

**Steps:**
- [x] Verify empty state (no cache + no server) shows suggested prompts correctly
- [x] Verify 502 from Edge Function shows "Ошибка AI-сервиса. Попробуй позже."
- [x] Verify `clearHistory` with no network shows error and keeps messages visible
- [x] Verify concurrent send + pagination doesn't corrupt message list (new message appends to end regardless of pagination state)
- [x] Test all messages > 48h shows empty state with suggested prompts
- [x] Verify daily limit banner still works (429 handling unchanged)

**Verification:** Manual QA walkthrough of all edge cases listed in spec. App behaves correctly in airplane mode, with server errors, and under normal operation.

---

## Supabase Changes
- **New RLS policy:** DELETE on `chat_messages` where `auth.uid() = user_id`
- **New index:** `idx_chat_messages_user_created` on `(user_id, created_at DESC)`
- **No new tables or columns**

## Test Coverage
- `ChatRepository`: mock `SupabaseClient` and `LocalStorage`, verify:
  - `fetchMessages` returns server data and caches it
  - `fetchMessages` falls back to cache on network error
  - `deleteAllMessages` clears server then cache
  - `loadCachedMessages` returns previously cached data
- `ChatNotifier`: mock repository, verify:
  - `build()` loads cache then refreshes
  - `loadMore()` paginates correctly
  - `sendMessage()` error shows error state (no mock)
  - `clearHistory()` error preserves messages

## Risks
- **Scroll position jump:** Prepending messages to ListView may cause visible scroll jump. May need `ScrollController` position adjustment or `key`-based preservation.
- **Cache staleness:** If user has been offline for days, cache shows stale messages (>48h) until server refresh completes. Acceptable per spec.
- **Supabase functions.invoke header access:** The current code reads headers from `response.data['_headers']` — this path may not work with all `supabase_flutter` versions. The daily limit display is Nice to Have, so not blocking.

## Out of Scope
- Реальный SSE-стриминг в UI (текст по буквам)
- Несколько чатов/сессий
- Смена AI-модели
- Изменения Edge Function
- Offline отправка (очередь)
- Клиентская запись в `chat_messages`
