# Plan: Admin Panel — Word Management

Source: ai_specs/004-admin-panel-spec.md
Created: 2026-05-26

## Overview

Build an in-app admin panel that lets whitelisted admin users create, edit, and manage vocabulary words in `daily_words`. The work is split into 6 stages: (1) DB migration to restructure `daily_words` and add admin infrastructure, (2) admin role detection on the client, (3) admin routing and scaffold, (4) Edge Function for AI word generation, (5) word creation UI with AI-assisted form, (6) word list and edit UI. Each stage builds on the previous one and is independently verifiable.

## Stages

### Stage 1: Database Migration

**Goal:** Restructure `daily_words` to match the `WordEntry` model, add admin email whitelist, admin role trigger, status/created_by columns, and updated RLS policies.

**Files to create/modify:**
- `supabase/migrations/{timestamp}_admin_panel.sql` — single migration with all DB changes

**Steps:**
- [x] Create `admin_emails` table (id uuid PK, email text UNIQUE, created_at timestamptz) with RLS enabled (no public access)
- [x] Seed `admin_emails` with `bahaarmanov88@gmail.com` and `test@test.com`
- [x] Create trigger function `handle_admin_role()` on `auth.users` BEFORE UPDATE: check if `NEW.email` exists in `admin_emails`, set `raw_app_meta_data = jsonb_set(raw_app_meta_data, '{role}', '"admin"')` if found, remove `role` key if not found
- [x] Restructure `daily_words`: rename `word_en` → `word`, `word_ru` → `translation`; add columns `ipa text`, `part_of_speech text NOT NULL DEFAULT 'noun'`, `level text NOT NULL DEFAULT 'a1'`, `definition_en text`, `definition_ru text`, `example_en text NOT NULL DEFAULT ''`, `example_ru text NOT NULL DEFAULT ''`, `topic text`, `tags jsonb NOT NULL DEFAULT '[]'::jsonb`, `alternative_translations jsonb NOT NULL DEFAULT '[]'::jsonb`, `updated_at timestamptz`
- [x] Add `status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived'))` and `created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL` to `daily_words`
- [x] Drop existing RLS policy `"Authenticated users can read daily_words"`. Create two new policies atomically: admin full CRUD (`FOR ALL USING (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')`), user read-only published (`FOR SELECT TO authenticated USING (status = 'published')`)
- [x] Recreate `get_todays_words()` RPC with `AND dw.status = 'published'` added to WHERE clause

**Verification:** Run `supabase db reset`. Confirm migration applies cleanly. Query `daily_words` — columns renamed, new columns present, existing seed data intact with `status = 'published'`. Confirm RPC still returns today's words. Confirm non-admin user can only SELECT published words via psql/Supabase Studio.

---

### Stage 2: Client-Side Admin Detection

**Goal:** Detect admin role from Supabase JWT and expose it via Riverpod provider. Update `WordEntry` model with `status` and `createdBy` fields. Update quiz queries to filter by published status.

**Files to create/modify:**
- `lib/src/features/admin/application/admin_provider.dart` — `isAdminProvider` reading from `appMetadata['role']`
- `lib/src/features/word_quiz/domain/word_entry.dart` — add `status` and `createdBy` fields
- `lib/src/features/word_quiz/domain/word_entry.freezed.dart` — regenerate
- `lib/src/features/word_quiz/domain/word_entry.g.dart` — regenerate
- `lib/src/features/word_quiz/data/word_quiz_repository.dart` — add `.eq('status', 'published')` to `fetchAllWords()`
- `lib/src/features/auth/application/auth_provider.dart` — add `refreshSession()` call on build

**Steps:**
- [x] Create `lib/src/features/admin/application/admin_provider.dart` with `isAdminProvider` — a `@Riverpod(keepAlive: true)` functional provider that reads `Supabase.instance.client.auth.currentUser?.appMetadata['role'] == 'admin'` and listens to auth state changes to stay reactive
- [x] Add `supabase.auth.refreshSession()` call in `AuthNotifier.build()` (after checking current session) to pick up metadata changes on app startup
- [x] Add `String? status` and `String? createdBy` fields to `WordEntry` freezed model (both nullable — existing quiz code doesn't need them)
- [x] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate freezed/json files
- [x] Update `fetchAllWords()` in `WordQuizRepository` to add `.eq('status', 'published')` filter

**Verification:** Sign in as `bahaarmanov88@gmail.com`, sign out, sign in again. Check that `isAdminProvider` returns `true`. Sign in as a non-admin user — `isAdminProvider` returns `false`. Run the quiz — words still load correctly, only published words appear.

---

### Stage 3: Admin Routing and Scaffold

**Goal:** Add admin routes to GoRouter with an admin guard, and create placeholder screens for the admin panel.

**Files to create/modify:**
- `lib/src/routing/app_router.dart` — add `AppRoute.admin`, `AppRoute.adminWordCreate`, `AppRoute.adminWordEdit` enum values; add admin routes outside ShellRoute; add admin guard to redirect logic
- `lib/src/routing/app_router.g.dart` — regenerate
- `lib/src/features/admin/presentation/admin_word_list_screen.dart` — placeholder screen
- `lib/src/features/admin/presentation/admin_word_form_screen.dart` — placeholder screen (reused for create and edit)
- `lib/src/features/profile/presentation/profile_screen.dart` — add admin entry point button (visible only when `isAdminProvider` is true)

**Steps:**
- [x] Add `admin`, `adminWordCreate`, `adminWordEdit` to `AppRoute` enum
- [x] Add three top-level GoRoutes outside the ShellRoute: `/admin` (word list), `/admin/create` (create form), `/admin/edit/:wordId` (edit form)
- [x] Add admin guard in the GoRouter redirect: if path starts with `/admin` and user is not admin, redirect to `/`
- [x] Create `AdminWordListScreen` placeholder (Scaffold with AppBar title "Управление словами", empty body)
- [x] Create `AdminWordFormScreen` placeholder accepting optional `wordId` parameter (Scaffold with AppBar, empty body)
- [x] Add an admin button in `ProfileScreen` (icon button with `admin_panel_settings` icon) that navigates to `/admin`, conditionally shown when `ref.watch(isAdminProvider)` is true
- [x] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate router

**Verification:** Sign in as admin — "Admin" button visible on profile screen, tapping it navigates to `/admin` placeholder. Sign in as non-admin — button hidden. Manually navigating to `/admin` as non-admin redirects to `/`.

---

### Stage 4: Edge Function — Generate Word Entry

**Goal:** Deploy a Supabase Edge Function that takes a word string, calls Claude API, and returns a structured WordEntry JSON.

**Files to create/modify:**
- `supabase/functions/generate-word-entry/index.ts` — new Edge Function

**Steps:**
- [x] Create the function file following the same structure as `supabase/functions/chat/index.ts`: CORS handler, auth verification via Bearer token + `supabase.auth.getUser(token)`
- [x] After auth, check `user.app_metadata?.role === 'admin'` — return 403 `{ error: "Forbidden" }` if not admin
- [x] Parse request body `{ "word": "serendipity" }`, validate word is a non-empty string
- [x] Call Claude API (same `CLAUDE_API_KEY`, `claude-sonnet-4-20250514` model) with a system prompt that instructs structured JSON output matching the WordEntry schema (snake_case keys matching DB columns)
- [x] Parse Claude's response, validate it's valid JSON, return it as `{ "data": { ... } }` with 200. On Claude API failure, return 502
- [ ] Test locally with `supabase functions serve` and a curl request (requires Docker)

**Verification:** Call the function with `curl` passing a valid admin Bearer token and `{ "word": "serendipity" }`. Confirm response contains all expected fields with sensible values. Call without auth — 401. Call as non-admin — 403.

---

### Stage 5: Word Creation Screen

**Goal:** Build the admin word creation flow: text input, AI generation, editable form, save as draft or published.

**Files to create/modify:**
- `lib/src/features/admin/data/admin_repository.dart` — CRUD operations on `daily_words`, duplicate check, call Edge Function
- `lib/src/features/admin/application/admin_word_form_notifier.dart` — form state management, AI generation, save logic
- `lib/src/features/admin/presentation/admin_word_form_screen.dart` — replace placeholder with full form UI
- `lib/src/features/admin/presentation/widgets/word_form_fields.dart` — extracted form fields widget (the form is large)

**Steps:**
- [x] Create `AdminRepository` with: `generateWordEntry(String word)` (calls Edge Function via `_client.functions.invoke('generate-word-entry', body: {'word': word})`), `createWord(WordEntry entry, {required String status})` (inserts into `daily_words` with `created_by = auth.uid()`), `checkDuplicateWord(String word)` (case-insensitive query on `word` column)
- [x] Create `AdminWordFormNotifier` (`@riverpod` auto-dispose class) with state holding: `WordEntry?` generated entry, `isGenerating` bool, `isSaving` bool, `error` string. Methods: `generate(String word)` — calls repo, sets state; `save({required String status})` — validates required fields, checks duplicate, calls repo
- [x] Build `AdminWordFormScreen` create mode: top section with text input + "Сгенерировать" button; loading state during generation; once generated, show editable form with all WordEntry fields (word, translation, IPA, part of speech dropdown, CEFR level dropdown, definitions, examples, tags as comma-separated, topic)
- [x] Extract form fields into `WordFormFields` widget to keep screen file under 300 lines
- [x] Add two action buttons at bottom: "Сохранить черновик" (saves with `status: 'draft'`) and "Опубликовать" (saves with `status: 'published'`). On success, navigate back to `/admin`
- [x] Handle edge cases: generation failure (show error + retry button, allow manual entry), incomplete AI response (pre-fill available fields), duplicate word warning

**Verification:** Navigate to `/admin/create`, type a word, tap Generate. AI returns a filled form. Edit a field, tap "Опубликовать" — word appears in `daily_words` via Supabase Studio with `status = 'published'` and `created_by` set. Repeat with "Сохранить черновик" — `status = 'draft'`. Try entering a duplicate word — warning shown.

---

### Stage 6: Word List and Edit Screens

**Goal:** Build the admin word list with status filtering and the word edit screen (reusing the form from Stage 5).

**Files to create/modify:**
- `lib/src/features/admin/data/admin_repository.dart` — add `fetchWords({String? status})`, `updateWord(WordEntry entry, {required String status})`, `fetchWordById(String id)`
- `lib/src/features/admin/application/admin_word_list_notifier.dart` — list state with filter
- `lib/src/features/admin/presentation/admin_word_list_screen.dart` — replace placeholder with full list UI
- `lib/src/features/admin/presentation/widgets/word_list_tile.dart` — list tile with status/level badges
- `lib/src/features/admin/presentation/widgets/status_filter_bar.dart` — filter chips for all/draft/published/archived
- `lib/src/features/admin/presentation/admin_word_form_screen.dart` — add edit mode (load existing word, pre-fill form, update on save)

**Steps:**
- [x] Add to `AdminRepository`: `fetchWords({String? statusFilter})` — queries `daily_words` ordered by `created_at` desc, optional status filter; `fetchWordById(String id)` — single word by ID; `updateWord(String id, Map<String, dynamic> updates)` — updates word row including status changes
- [x] Create `AdminWordListNotifier` (`@riverpod` auto-dispose class) with state: list of words, active filter (all/draft/published/archived), loading/error states. Methods: `loadWords()`, `setFilter(String? status)` — reloads with filter
- [x] Build `AdminWordListScreen`: AppBar with title "Управление словами", `StatusFilterBar` below AppBar (filter chips), scrollable `ListView` of `WordListTile` widgets, FAB "+" navigating to `/admin/create`. Empty state when no words match filter
- [x] Create `WordListTile`: shows word, translation, CEFR level badge (colored chip), status badge (colored chip: green=published, orange=draft, grey=archived), created date. Tap navigates to `/admin/edit/:wordId`
- [x] Update `AdminWordFormScreen` to support edit mode: when `wordId` path parameter is present, load word from `AdminRepository.fetchWordById()`, pre-fill all form fields, change buttons to "Обновить" and status change actions (draft ↔ published ↔ archived)
- [x] Add confirmation dialog when changing status from published → archived ("Слово будет убрано из квизов. Продолжить?")

**Verification:** Navigate to `/admin` — see all words with badges. Filter by "draft" — only drafts shown. Filter by "published" — only published shown. Tap a word — edit form opens pre-filled. Change a field, tap save — word updated in DB. Change status from published to archived — confirmation dialog appears, on confirm word updates. Navigate to quiz — archived word no longer appears. Empty state shows when filtering a status with no words.

---

## Database Changes

All in a single migration (`{timestamp}_admin_panel.sql`):

| Change | Table | Details |
|--------|-------|---------|
| Create | `admin_emails` | id uuid PK, email text UNIQUE, created_at timestamptz DEFAULT now() |
| Seed | `admin_emails` | `bahaarmanov88@gmail.com`, `test@test.com` |
| Create trigger | `auth.users` | `on_auth_user_updated` AFTER UPDATE — sets/removes `raw_app_meta_data.role` |
| Rename columns | `daily_words` | `word_en` → `word`, `word_ru` → `translation` |
| Add columns | `daily_words` | `ipa`, `part_of_speech`, `level`, `definition_en`, `definition_ru`, `example_en`, `example_ru`, `topic`, `tags`, `alternative_translations`, `updated_at`, `status`, `created_by` |
| Drop + create RLS | `daily_words` | Admin: full CRUD via `app_metadata.role`. Users: SELECT published only |
| Update RPC | `get_todays_words()` | Add `AND dw.status = 'published'` |

## Edge Functions

| Function | Method | Auth | Input | Output |
|----------|--------|------|-------|--------|
| `generate-word-entry` | POST | Bearer token + admin role check | `{ "word": "string" }` | `{ "data": { WordEntry JSON } }` |

## Test Coverage

- **Unit tests:** `WordEntry` model — verify `fromJson`/`toJson` roundtrip with new `status` and `createdBy` fields, verify nullable fields handled correctly
- **Manual testing:** Full admin flow end-to-end (create word via AI, edit, change status, verify quiz only shows published). Non-admin access blocked at route and RLS levels. Existing quiz flow unchanged.

## Risks

- **Trigger on `auth.users`**: Writing to `raw_app_meta_data` from a trigger on the same table is a known Supabase pattern but may have edge cases with concurrent sign-ins. If issues arise, fallback to calling `supabase.auth.admin.updateUserById()` from the Edge Function instead.
- **Column rename breaks `get_todays_words()` RPC**: The RPC uses `SELECT dw.*` so column renames propagate automatically. But if any other code references `word_en`/`word_ru` directly (check before applying migration), it will break.
- **Edge Function cold starts**: First call to `generate-word-entry` may be slow (~2-5s). The UI already plans for a loading state, so this is acceptable.
- **Freezed model JSON key mapping**: The DB uses `snake_case` (`part_of_speech`, `definition_en`) while Dart uses `camelCase` (`partOfSpeech`, `definitionEn`). Verify `build.yaml` has `field_rename: snake` for json_serializable, or add `@JsonKey(name: 'part_of_speech')` annotations. The current `WordEntry` model does not have these annotations — check if build.yaml handles it.

## Out of Scope

- Linking published words to daily quiz rotation (`daily_word_sets`) — separate feature
- User-facing changes to quiz beyond filtering by `status = 'published'`
- Admin user management (adding/removing admins is DB-only for now)
- Bulk word import (CSV, etc.)
- Word usage analytics
- Push notifications for new published words
