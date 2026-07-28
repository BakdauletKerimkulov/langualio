# Spec: Admin Panel — Word Management

Created: 2026-05-26
Status: refined

## Goal

Give designated admin users the ability to create, review, edit, and manage vocabulary words through an in-app admin panel. An AI assistant generates full word entries from a single input word, and admins control word lifecycle via draft/published/archived statuses.

## Background

Currently, words in the `daily_words` table are seeded manually via SQL migrations. There is no in-app mechanism to add or manage vocabulary. The app needs a content management flow so admins can grow the word library without touching the database directly.

The `WordEntry` Dart model (uncommitted) has rich fields (translation, IPA, examples, definitions, tags, CEFR level, part of speech) but the `daily_words` DB table still only has `word_en`, `word_ru`, `created_at`. The table must be restructured to match the model before admin CRUD can work. There is no status field on either side, and no admin role system — all authenticated users have the same permissions.

## User Flow

### Admin Detection (on login)

1. User signs in with email/password (existing flow).
2. A Supabase DB trigger on `auth.users` UPDATE (fires when `last_sign_in_at` changes) checks if the user's email exists in the `admin_emails` table.
3. If found, the trigger sets `raw_app_meta_data.role = 'admin'` on `auth.users`. If not found, it removes the `role` key (handles admin revocation).
4. The client calls `supabase.auth.refreshSession()` on app startup to pick up any metadata changes (JWT caches claims for up to 1 hour).
5. The client reads `appMetadata['role']` and exposes an `isAdmin` flag via a Riverpod provider.
6. If admin, the app shows an "Admin" entry point (e.g., icon button in the app bar or profile screen).

**Note:** The admin role will only take effect after the user's next sign-in (when the trigger fires). First-time signup won't set the role — the user must sign out and sign back in after being added to `admin_emails`.

### Word Creation

1. Admin navigates to the Admin Panel via route `/admin`.
2. Admin sees a word list screen showing all words with status badges and filters.
3. Admin taps "+" FAB to create a new word.
4. Admin enters a word (e.g., "serendipity") and taps "Generate".
5. An Edge Function calls Claude API to generate a full `WordEntry` JSON (translation, IPA, part of speech, CEFR level, definitions, examples, tags, alternative translations).
6. The generated entry is displayed in an editable form.
7. Admin reviews and optionally edits any field.
8. Admin taps either **"Save as Draft"** or **"Publish"** button at the bottom.
9. The word is saved to `daily_words` with the chosen status.

### Word List & Management

1. Admin sees all words in a scrollable list, sorted by `created_at` desc.
2. Each list tile shows: word, translation, CEFR level badge, status badge, created date.
3. Filter bar at top allows filtering by status (all / draft / published / archived).
4. Tapping a word opens the edit screen (same form as creation, pre-filled).
5. Admin can change any field and update the status.
6. All status transitions are allowed: draft ↔ published ↔ archived.

## Requirements

### Must Have

- [ ] `admin_emails` table in Supabase with seeded entries: `bahaarmanov88@gmail.com`, `test@test.com`
- [ ] DB trigger on `auth.users` UPDATE that checks `admin_emails` and sets/removes `raw_app_meta_data.role`
- [ ] RLS policies on `daily_words` allowing admin full CRUD (using `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'`)
- [ ] `status` column on `daily_words` table (enum: `draft`, `published`, `archived`, default `published`)
- [ ] `daily_words` table restructured: rename `word_en` → `word`, `word_ru` → `translation`, add all WordEntry columns (`ipa`, `part_of_speech`, `level`, `definition_en`, `definition_ru`, `example_en`, `example_ru`, `topic`, `tags`, `alternative_translations`)
- [ ] `created_by` column on `daily_words` (uuid, nullable, references `auth.users` ON DELETE SET NULL — nullable because existing seed words have no creator)
- [ ] `isAdmin` Riverpod provider derived from Supabase `appMetadata`
- [ ] Admin route `/admin` with auth + admin guard in GoRouter
- [ ] Word list screen with status filter (all / draft / published / archived)
- [ ] Word creation screen: text input → AI generate → editable form → save
- [ ] Edge Function `generate-word-entry` that takes a word string, calls Claude API, returns full WordEntry JSON
- [ ] Word edit screen (reuses creation form, pre-filled with existing data)
- [ ] Status change capability from edit screen (draft ↔ published ↔ archived)
- [ ] `WordEntry` model updated with `status` and `createdBy` fields
- [ ] `get_todays_words()` RPC updated with `WHERE dw.status = 'published'` (this function is `SECURITY DEFINER` so RLS doesn't apply to it)
- [ ] `fetchAllWords()` in `WordQuizRepository` updated with `.eq('status', 'published')` filter (defense-in-depth alongside RLS)
- [ ] Track which admin created each word (`created_by` field)

### Nice to Have

- [ ] Search words by text in the word list
- [ ] Sort word list by different columns (word, level, status, date)
- [ ] Bulk status change (select multiple → archive/publish)
- [ ] Word count stats on the admin panel (total / by status / by level)

## Technical Constraints

### Database

- New table: `admin_emails` (id uuid PK, email text UNIQUE, created_at timestamptz)
- New trigger: `on_auth_user_updated` — after UPDATE on `auth.users`, check `admin_emails`, set/remove `raw_app_meta_data.role`. Must handle both granting and revoking admin role.
- Restructure `daily_words` table:
  - Rename `word_en` → `word`, `word_ru` → `translation`
  - Add columns: `ipa text`, `part_of_speech text NOT NULL DEFAULT 'noun'`, `level text NOT NULL DEFAULT 'a1'`, `definition_en text`, `definition_ru text`, `example_en text NOT NULL DEFAULT ''`, `example_ru text NOT NULL DEFAULT ''`, `topic text`, `tags jsonb NOT NULL DEFAULT '[]'`, `alternative_translations jsonb NOT NULL DEFAULT '[]'`, `updated_at timestamptz`
  - Add `status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived'))`
  - Add `created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL` (nullable — existing seed words have no creator)
  - Backfill existing seed words: set `example_en = ''`, `example_ru = ''` (or meaningful defaults) so NOT NULL constraints pass
- RLS policy changes (must be done atomically in one migration):
  1. Drop existing policy `"Authenticated users can read daily_words"`
  2. Create admin policy: `FOR ALL USING (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')` — full CRUD
  3. Create user policy: `FOR SELECT TO authenticated USING (status = 'published')` — read-only, published only
- Update `get_todays_words()` RPC: add `AND dw.status = 'published'` to WHERE clause (SECURITY DEFINER bypasses RLS)

### Edge Function

- `generate-word-entry`: receives `{ "word": "serendipity" }`, returns full WordEntry JSON
- Uses Claude API (same pattern as existing chat Edge Function)
- **Must verify caller is admin:** check `user.app_metadata.role === 'admin'` after auth, return 403 if not admin
- System prompt instructs Claude to return structured JSON matching WordEntry schema
- Response must include: word, translation (Russian), IPA, part of speech, CEFR level, definitions (EN/RU), examples (EN/RU), alternative translations, suggested tags

### Architecture

- Feature folder: `lib/src/features/admin/` with standard layers (domain, data, application, presentation)
- Repository: `AdminRepository` — CRUD operations on `daily_words` with status filtering
- Notifier: `AdminWordListNotifier` — manages word list state with filters
- Notifier: `AdminWordFormNotifier` — manages word creation/edit form state and AI generation
- Reuse existing `WordEntry` model (extended with status + createdBy)
- Provider: `isAdminProvider` — reads from `supabase.auth.currentUser?.appMetadata['role']`
- On app startup, call `supabase.auth.refreshSession()` to pick up any metadata changes (admin role grant/revoke)

### Routing

- New route: `AppRoute.admin` → `/admin` (word list screen)
- New route: `AppRoute.adminWordCreate` → `/admin/create` (create screen)
- New route: `AppRoute.adminWordEdit` → `/admin/edit/:wordId` (edit screen)
- All admin routes placed as **top-level GoRoutes outside the ShellRoute** (no bottom navigation bar), same level as `/chat` and `/quiz`
- Guard: redirect to `/` if user is not admin

## Edge Cases

- **User not in whitelist tries `/admin` route**: GoRouter redirect sends them to home.
- **Admin email removed from whitelist**: On next sign-in, the trigger removes `role` from `raw_app_meta_data`. Active session may still have old JWT until expiry (up to 1 hour) — RLS is the real guard. Client-side `refreshSession()` on app startup helps pick up changes sooner.
- **AI generation fails**: Show error state with retry button. Allow manual entry of all fields as fallback.
- **AI returns incomplete data**: Pre-fill what's available, highlight empty required fields for admin to complete manually.
- **Duplicate word**: Check if `word` (case-insensitive) already exists in `daily_words` before saving. Show warning with link to existing entry. Consider adding a unique index on `lower(word)` at the DB level.
- **Empty word list**: Show empty state with prompt to create first word.
- **Long AI generation time**: Show loading indicator with the word being generated. Disable form until generation completes.
- **Admin saves draft then publishes**: Status transitions are immediate, no confirmation needed for draft → published. Consider confirmation for published → archived (removes from quiz pool).
- **Concurrent admin edits**: Last-write-wins (simple for now, no real-time collaboration needed).

## Out of Scope

- Linking published words to daily quiz rotation (`daily_word_sets`) — separate feature
- User-facing changes to quiz beyond filtering by `status = 'published'`
- Admin user management (adding/removing admins is DB-only for now)
- Bulk word import (CSV, etc.)
- Word usage analytics
- Push notifications for new published words

## Definition of Done

- [ ] All Must Have requirements implemented
- [ ] Migration creates `admin_emails` table, trigger, and alters `daily_words`
- [ ] Edge Function `generate-word-entry` deployed and working
- [ ] Admin can create a word via AI generation, edit it, and save as draft or published
- [ ] Admin can view all words filtered by status
- [ ] Admin can edit any word and change its status
- [ ] Non-admin users cannot access admin routes or see admin-only words (draft/archived)
- [ ] Existing quiz flow unaffected (only shows published words)
- [ ] Edge cases handled (errors, duplicates, empty states)
- [ ] Code follows project conventions (Riverpod, Freezed, GoRouter, feature-first structure)
