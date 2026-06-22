# Plan: Refactor Quiz Repository — Local-Only Words + User Word Addition

Source: `ai_specs/009-refactor-quiz-repo-spec.md`
Created: 2026-06-21
Status: in-progress

## Overview
Remove the remote word-fetching layer (`WordQuizRepository`), replace with a local-only word pool (asset JSON + user Drift words), and add a user-facing "Add word" flow powered by the existing `generate-word-entry` Edge Function (with admin check removed and per-user rate limiting added).

**Spec:** `ai_specs/009-refactor-quiz-repo-spec.md`

## Context
- **Structure:** feature-first (`lib/src/features/word_quiz/{domain,data,application,presentation}`)
- **State management:** Riverpod code-gen (`@riverpod`). Controllers auto-dispose, repositories `keepAlive: true`. Cited: `lib/src/features/word_quiz/application/word_quiz_notifier.dart`
- **Reference implementations:**
  - `AssetWordRepository` + `assetWordsProvider` (`data/local/asset_word_repository.dart`) — local repo pattern
  - `AdminRepository.generateWordEntry()` (`lib/src/features/admin/data/admin_repository.dart:22-46`) — Edge Function call + response parsing
  - `WordEntriesTable` + Drift ↔ domain extensions (`data/local/word_entries_table.dart:26-62`)
- **Testing convention:** mirrored `test/src/features/`, `group()`, mock repos for controller tests. Cited: `ai_toolkit/architecture.md` §Testing
- **Lint + test command:** `dart analyze && flutter test`
- **Assumptions / Gaps:**
  - `uuid` package not in `pubspec.yaml` — must add it (R3 requires UUID generation for `id` field)
  - Rate-limit tracking for Edge Function uses `user_daily_usage` table with `message_count` column — need a separate column or key for word generations vs. chat messages. Spec says "reuse the pattern" but column semantics differ. **Assumption:** add a `generation_count` column or use a separate row key (e.g., `type` column). Will flag in implementation.

## Plan

### Phase 1 — Thin vertical slice: local word pool + notifier refactor
**Goal:** Remove remote word fetching, wire `WordPoolProvider` to merge asset + Drift words, prove quiz loads from local sources end-to-end.

- [x] `lib/src/features/word_quiz/domain/word_entry.dart` — rename `WordSource.server` → `WordSource.user`
- [x] `lib/src/features/word_quiz/data/local/user_word_repository.dart` — create `UserWordRepository` wrapping Drift `WordEntriesTable` with `fetchAll()`, `insert(WordEntry)`, `existsByWord(String)`. Add `uuid` dependency to `pubspec.yaml`
- [x] TDD: `UserWordRepository.fetchAll` returns inserted words; `insert` generates UUID id; `existsByWord` returns true for existing word (case-insensitive)
- [x] `lib/src/features/word_quiz/application/word_pool_provider.dart` — create functional `@riverpod` provider merging `assetWordsProvider` + `UserWordRepository.fetchAll()`, dedup by `word` (case-insensitive, user wins), tag user words with `WordSource.user`
- [x] TDD: `WordPoolProvider` merges sources; user word overrides asset word with same `word` field; user words tagged `WordSource.user`
- [x] `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — consume `wordPoolProvider` instead of remote fetch. Remove `_repo` (WordQuizRepository), remote fetch, cache, and merge logic. Keep attempt fetching via `QuizAttemptRepository` (extracted from `WordQuizRepository`)
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test`

### Phase 2 — Cleanup: delete remote repo, stub, and SharedPrefs cache keys
**Goal:** Remove dead code and SharedPreferences caching keys related to remote words.

- [x] Delete `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart` + `.g.dart`
- [x] Delete `lib/src/features/word_quiz/data/local/local_word_quiz_repo.dart` + `.g.dart`
- [x] Remove SharedPreferences keys `word_quiz_today_words`, `word_quiz_today_day`, `word_quiz_pending_attempts` usage from codebase (verify no remaining references)
- [x] Fix all broken imports across codebase (grep for deleted files)
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test`

### Phase 3 — Word generation service + AddWordNotifier
**Goal:** Extract shared word generation logic and build the add-word state machine.

- [x] `lib/src/features/word_quiz/data/word_generation_service.dart` — extract `generateWordEntry(String word)` from `AdminRepository` into a shared service. Inject `SupabaseClient`. Both `AdminRepository` and `AddWordNotifier` will consume this
- [x] `lib/src/features/admin/data/admin_repository.dart` — refactor to delegate to `WordGenerationService` instead of inline Edge Function call
- [x] `lib/src/features/word_quiz/application/add_word_notifier.dart` — create `AddWordNotifier` (auto-dispose `@riverpod` class, Pattern 2). `AddWordState` with: `WordEntry? preview`, `bool isGenerating`, `bool isSaving`, `String? error`, `bool saved`. Methods: `generate(word)` calls `WordGenerationService`, checks duplicates in both Drift and asset pool; `save()` inserts into Drift via `UserWordRepository`
- [x] TDD: `AddWordNotifier` state transitions: initial → generating → preview → saving → saved; duplicate word detected → error state; generation failure → error with retry possible
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test`

### Phase 4 — Add-word screen + navigation
**Goal:** User-facing UI for adding custom words, wired into quiz home.

- [ ] `lib/src/routing/app_router.dart` — add `AppRoute.addWord` enum value, route `/practice/add-word` nested or standalone, builder for `AddWordScreen`
- [ ] `lib/src/features/word_quiz/presentation/add_word_screen.dart` — text field, "Generate" button, loading state, preview card (word, IPA, level, meanings with translations/examples), "Save" button. Error states with retry. All strings `.hardcoded`
- [ ] `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` — add "Add word" button/FAB navigating to `AppRoute.addWord`
- [ ] Verify: `dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test`

### Phase 5 — Edge Function: remove admin check + add rate limiting
**Goal:** Any authenticated user can generate words, with 10/day rate limit.

- [ ] `supabase/functions/generate-word-entry/index.ts` — remove admin role check (keep auth check). Add per-user rate limiting: query `user_daily_usage` for today's `generation_count`, return 429 if ≥ 10, increment after successful generation
- [ ] `lib/src/features/word_quiz/application/add_word_notifier.dart` — handle 401, 429, 502 error codes from Edge Function with appropriate user-facing error messages
- [ ] Verify: deploy Edge Function to staging, manual test with non-admin user

### Phase 6 — Nice-to-haves (optional)
**Goal:** User word count display and visual distinction in quiz.

- [ ] `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` — show user word count (N1: "12 custom words")
- [ ] Quiz word card — visual badge/accent for `WordSource.user` words (N2)
- [ ] Verify: `dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test`

## Data layer changes
- No new Drift migrations — `WordEntriesTable` already exists with all required columns
- `user_daily_usage` table — needs a `generation_count` column (or separate tracking mechanism) for word generation rate limiting. Requires Supabase migration.
- No changes to `word_quiz_attempts` or `word_learning_progress` tables

## External integrations
- `generate-word-entry` Edge Function: auth required, rate limit 10/day per user via `user_daily_usage`. Returns `WordEntry` JSON. Error codes: 401, 429, 502, 500

## Risks
- **Attempt repository coupling:** `WordQuizNotifier` currently uses `WordQuizRepository` for both word fetching AND attempt saving. Removing the repo requires extracting attempt logic into a separate provider or keeping a slim version. Mitigation: create a focused `QuizAttemptRepository` or inline the 3 Supabase calls.
- **Rate limit column conflict:** `user_daily_usage` currently tracks `message_count` for chat. Adding `generation_count` requires a migration. Mitigation: simple `ALTER TABLE ADD COLUMN` with default 0.
- **`uuid` package addition:** New dependency. Mitigation: well-maintained, widely used, minimal risk.

## Out of scope
- NOT implementing edit/delete for user-added words
- NOT syncing user words to Supabase
- NOT changing the admin panel (continues to manage `daily_words` independently)
- NOT changing quiz UI/UX beyond adding the "add word" entry point
- NOT removing Supabase attempt/progress tracking
- NOT implementing word import/export
- NOT adding word categories or filtering
