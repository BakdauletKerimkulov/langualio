# Spec: Refactor Quiz Repository — Local-Only Words + User Word Addition

Created: 2026-06-21
Status: refined
Refined: 2026-06-21
Source request: ai_specs/009-refactor-quiz-repo.md

## Goal

Simplify the word quiz data layer to use only local word sources (bundled asset JSON + user words in Drift), remove all remote word fetching/caching logic, and add a user-facing flow for adding custom words via AI generation. A new word service merges both sources into a single quiz pool.

## Background

**Stack & conventions:** Flutter + Riverpod (code-gen `@riverpod`), feature-first architecture with domain/data/application/presentation layers (`ai_toolkit/architecture.md`). Repositories live in `data/`, accept and return domain models. Controllers are auto-dispose `@riverpod` classes; repositories are `@Riverpod(keepAlive: true)`. Domain models are pure Dart with freezed (`ai_toolkit/code-style.md`). Supabase is the backend (`ai_docs/PROJECT.md`).

**Project context:** The word quiz currently has a dual-source design:
- **Asset words** loaded from `assets/data/b1_words.json` via `AssetWordRepository` (`lib/src/features/word_quiz/data/local/asset_word_repository.dart`)
- **Server words** fetched via `get_todays_words()` RPC in `WordQuizRepository` (`lib/src/features/word_quiz/data/remote/word_quiz_repository.dart`), with local caching in SharedPreferences and an offline attempt queue
- Merging happens inside `WordQuizNotifier.build()` (`lib/src/features/word_quiz/application/word_quiz_notifier.dart:33-69`)
- A Drift table `WordEntriesTable` exists (`lib/src/features/word_quiz/data/local/word_entries_table.dart`) but is unused
- `LocalWordQuizRepo` (`lib/src/features/word_quiz/data/local/local_word_quiz_repo.dart`) is a stub with no queries
- The admin panel already calls `generate-word-entry` Edge Function to create words via Claude AI (`lib/src/features/admin/data/admin_repository.dart:22-46`)
- Quiz attempts and learning progress are tracked in Supabase tables (`word_quiz_attempts`, `word_learning_progress`)

**Why now / why this approach:** The bundled B1 asset words make the remote word pool redundant for the current MVP. Removing remote complexity simplifies the codebase. Adding user words via Drift enables personalized vocabulary without server-side word management.

## User Flow

### Happy path

1. User opens quiz home (`WordQuizHomeScreen`) -> `WordQuizNotifier` loads words from `WordPoolProvider` (asset + user Drift words merged) -> quiz session displays word count and progress.
2. User taps "Start" -> quiz plays as before with mixed word pool.
3. User taps "Add word" button on quiz home -> navigates to add-word screen.
4. User types an English word, taps "Generate" -> Edge Function `generate-word-entry` returns a `WordEntry` preview (word, IPA, meanings, level, examples).
5. User reviews the preview, taps "Save" -> word is inserted into Drift `word_entries` table.
6. User returns to quiz home -> next quiz session includes the new word in the pool.

### Alternative flows

- If the word already exists in the user's Drift table OR in the asset word pool (case-insensitive match on `word` field), show a message "This word is already in your collection" and do not save a duplicate.
- If the user cancels on the preview screen, nothing is saved.

### Error & recovery flows

- If the Edge Function call fails (network error, 502), show an error message with a "Retry" button. The typed word remains in the text field.
- If the Edge Function returns 401 (unauthenticated), show "Please sign in again" error.
- If the Edge Function returns 429 (rate limited), show "Daily limit reached. Try again tomorrow." message.
- If Drift insert fails, show a generic error snackbar.

### Edge cases

- Empty state: no user words in Drift — quiz uses asset words only. No degradation.
- First-time use: identical to empty state. "Add word" button is always visible.
- Large dataset: user adds 500+ words — `WordPoolProvider` returns all. Quiz session still picks from the full pool. No pagination needed (in-memory list is fine for <10k entries).
- Offline: "Add word" requires network (Edge Function call). Quiz itself works fully offline (asset + Drift words are local). Attempts still queue locally if Supabase is unreachable (existing behavior).

## Requirements

### Must Have

- [ ] R1: Remove `WordQuizRepository` (`data/remote/word_quiz_repository.dart`) and its provider. Verifiable by: file deleted, no imports reference it, `dart analyze` clean.
- [ ] R2: Rename `WordSource` enum values from `{ asset, server }` to `{ asset, user }`. Keep the `source` field on `WordEntry` (needed for N2 visual distinction). `WordPoolProvider` tags user-sourced words with `WordSource.user` at merge time. Verifiable by: `WordSource.server` not found in codebase, `WordEntry.fromJson`/`toJson` still work, build_runner generates clean.
- [ ] R3: Implement `UserWordRepository` in `data/local/user_word_repository.dart` wrapping Drift `WordEntriesTable` with methods: `fetchAll() -> Future<List<WordEntry>>`, `insert(WordEntry) -> Future<void>`, `existsByWord(String) -> Future<bool>`. The `insert` method must generate a UUID for the `id` field (using `uuid` package) and set `createdBy` to the current user's ID before writing to Drift. Verifiable by: unit test for each method.
- [ ] R4: Create `WordPoolProvider` (functional auto-dispose `@riverpod` provider) in `application/` that merges `assetWordsProvider` + `UserWordRepository.fetchAll()` into a single `Future<List<WordEntry>>`. Tags user words with `WordSource.user` at merge time. Deduplication by `word` field (case-insensitive; user words override asset words with same word). Auto-dispose ensures re-computation on screen re-mount, picking up newly added words without manual invalidation. Verifiable by: provider returns combined list; duplicate words resolved correctly; user words tagged with `WordSource.user`.
- [ ] R5: Update `WordQuizNotifier.build()` to consume `WordPoolProvider` instead of fetching from remote. Remove all remote fetch, cache, and merge logic. Keep attempt fetching from Supabase. Verifiable by: quiz loads words from local sources only; attempts still saved to Supabase.
- [ ] R6: Remove SharedPreferences caching keys (`word_quiz_today_words`, `word_quiz_today_day`, `word_quiz_pending_attempts`) and related logic from the codebase. Verifiable by: keys not found in codebase.
- [ ] R7: Add "Add word" screen (`presentation/add_word_screen.dart`) with: text field for English word, "Generate" button, loading state, preview of generated `WordEntry` (word, IPA, level, meanings with translations and examples), "Save" button. Verifiable by: manual QA — full flow from input to saved word.
- [ ] R8: Create `AddWordNotifier` (`application/add_word_notifier.dart`) as auto-dispose `@riverpod` class (Pattern 2 from `ai_toolkit/riverpod.md`). State class `AddWordState` with fields: `WordEntry? preview`, `bool isGenerating` (loading for generate), `bool isSaving` (loading for save), `String? error`, `bool saved`. Methods: `generate(String word) -> Future<void>` (calls Edge Function via shared word generation service), `save() -> Future<bool>` (inserts into Drift, sets `saved = true`). After successful save, show success snackbar and `context.pop()`. Verifiable by: state transitions match expected flow: initial → generating → preview → saving → saved.
- [ ] R9: Remove admin role check from `generate-word-entry` Edge Function. Any authenticated user can call it. Add per-user rate limiting: max 10 word generations per day, tracked via `user_daily_usage` table (reuse the pattern from chat message limits). Return 429 if limit exceeded. Verifiable by: non-admin user successfully generates a word entry; 11th generation in same day returns 429.
- [ ] R10: Add navigation to add-word screen from `WordQuizHomeScreen` (button or FAB). Add `AppRoute.addWord` to the `AppRoute` enum. Route path: nested under practice branch (e.g. `/practice/add-word`). Navigate with `context.pushNamed(AppRoute.addWord.name)`. Verifiable by: button visible, navigates to add-word screen.
- [ ] R11: Remove `LocalWordQuizRepo` stub (`data/local/local_word_quiz_repo.dart`). Verifiable by: file deleted, no imports reference it.

### Nice to Have

- [ ] N1: Show user word count on quiz home (e.g., "12 custom words"). Verifiable by: count displayed, updates after adding a word.
- [ ] N2: Visual distinction for user-added words in quiz (e.g., small badge or different card accent). Verifiable by: visual difference visible during quiz.

### Non-functional

- Performance: merged word pool loads in <200ms for 2000 total words (asset + user).
- Accessibility: add-word screen text field and buttons meet minimum 48dp tap target.
- i18n: all new UI strings use `.hardcoded` extension for future extraction.

## Technical Constraints

**Files to create:**
- `lib/src/features/word_quiz/data/local/user_word_repository.dart` — Drift-backed CRUD for user words
- `lib/src/features/word_quiz/data/word_generation_service.dart` — shared Edge Function call logic (extracted from `AdminRepository`)
- `lib/src/features/word_quiz/application/word_pool_provider.dart` — merges asset + user words
- `lib/src/features/word_quiz/application/add_word_notifier.dart` — controls add-word flow (with `AddWordState` class)
- `lib/src/features/word_quiz/presentation/add_word_screen.dart` — add-word UI

**Files to modify:**
- `lib/src/features/word_quiz/domain/word_entry.dart` — rename `WordSource` values from `{ asset, server }` to `{ asset, user }`
- `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — consume `WordPoolProvider`, remove remote logic
- `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` — add "Add word" button/navigation
- `lib/src/routing/app_router.dart` — add route for add-word screen
- `supabase/functions/generate-word-entry/index.ts` — remove admin role check (keep auth check)
- `lib/src/core/local_storage/drift.dart` — no changes needed (already includes `WordEntriesTable`)

**Files to delete:**
- `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart`
- `lib/src/features/word_quiz/data/remote/word_quiz_repository.g.dart`
- `lib/src/features/word_quiz/data/local/local_word_quiz_repo.dart`

**Patterns to follow (with citations):**
- Follow `AssetWordRepository` (`data/local/asset_word_repository.dart`) for local repository pattern and provider structure.
- Follow `AdminRepository.generateWordEntry()` (`lib/src/features/admin/data/admin_repository.dart:22-46`) for Edge Function call and response parsing.
- Follow `WordEntriesTableDataX.toModel()` and `WordEntryX.toCompanion()` extensions (`data/local/word_entries_table.dart:28-62`) for Drift <-> domain mapping.
- Follow Riverpod Pattern 2 (custom state notifier from `ai_toolkit/riverpod.md`) for `AddWordNotifier`. State class: `AddWordState` with `WordEntry? preview`, `bool isGenerating`, `bool isSaving`, `String? error`, `bool saved`.

**Anti-patterns / avoid:**
- Do not add SharedPreferences caching for user words — Drift is the single local store.
- Do not duplicate the Edge Function call logic — extract `generateWordEntry()` from `AdminRepository` into a shared `WordGenerationService` in `lib/src/features/word_quiz/data/word_generation_service.dart` (or `core/`). Both `AdminRepository` and `AddWordNotifier` consume this shared service.
- Do not create a new Drift table — reuse existing `WordEntriesTable`.

**Data layer changes:**
- No new Drift migrations needed — `WordEntriesTable` already exists with all required columns.
- No Supabase schema changes — attempts and progress tables remain unchanged.

**External integrations:**
- `generate-word-entry` Edge Function: called by `AddWordNotifier` via shared `WordGenerationService`. Requires network + Supabase auth token. Returns `WordEntry` JSON. Rate limits: 10 generations/day per user (tracked via `user_daily_usage`). Failure mode: 401/429/502/500 — handled in notifier with error state. 429 shows "Daily limit reached" message.

## Edge Cases

Cross-reference with User Flow -> Edge cases above. Additional:
- User tries to add a word that matches an asset word by `word` field — blocked by duplicate check (checks both Drift and asset pool). User sees "This word is already in your collection."
- Drift database reset (app reinstall) — user words lost. Asset words unaffected. Acceptable for MVP.

## Out of Scope

- NOT implementing edit/delete for user-added words — deferred to a future spec. Users can only add.
- NOT syncing user words to Supabase — words stay local-only in Drift.
- NOT changing the admin panel — it continues to manage `daily_words` table independently for server-side word management.
- NOT changing quiz UI/UX beyond adding the "add word" entry point — quiz play screen, completion view, language selector unchanged.
- NOT removing Supabase attempt/progress tracking — those stay remote.
- NOT implementing word import/export.
- NOT adding word categories or filtering in the quiz.

## Validation

**Automated tests:**
- Unit: `UserWordRepository` — insert, fetchAll, existsByWord (mock Drift or in-memory DB)
- Unit: `WordPoolProvider` — merges two sources, deduplicates by id
- Unit: `AddWordNotifier` — state transitions: idle -> loading -> preview -> saved; error states
- Unit: `WordQuizNotifier` — loads from `WordPoolProvider` instead of remote; still fetches attempts from Supabase

**Manual QA scenarios:**
1. Given fresh install with no user words, when opening quiz, then quiz loads asset words only and works normally.
2. Given user on quiz home, when tapping "Add word", then add-word screen opens with empty text field.
3. Given user on add-word screen types "ephemeral" and taps Generate, then loading indicator shows, then preview displays with word details (IPA, level, meanings).
4. Given preview is shown, when tapping Save, then word is saved to Drift and user returns to quiz home.
5. Given user just added "ephemeral", when starting a new quiz, then "ephemeral" appears in the word pool.
6. Given user tries to add "ephemeral" again, then duplicate message is shown and save is blocked.
7. Given no network, when tapping Generate on add-word screen, then error message appears with Retry button.
8. Given non-admin user, when calling generate-word-entry, then word is generated successfully (no 403).

**Expected behavior under edge conditions:**
- Offline -> quiz works (local words), "Add word" Generate fails with error message
- Supabase error -> quiz words still load (local), attempt save queues or fails gracefully
- Empty Drift table -> quiz uses asset words only, no crash

## Definition of Done

- [ ] All Must Have requirements pass automated tests
- [ ] All Manual QA scenarios pass on iOS simulator
- [ ] `dart analyze` reports no new warnings
- [ ] `build_runner build` completes without errors
- [ ] No new lint warnings; matches `ai_toolkit/` style guide
- [ ] Edge Function deployed with admin check removed
- [ ] Spec file linked in the PR description
