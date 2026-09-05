# Plan: Daily Word Quiz

Source: ai_specs/001-word-quiz-spec.md
Created: 2026-05-14

## Overview

Replace the existing mock Practice feature with a production-ready daily word quiz backed by Supabase. This involves: a new database migration (4 tables, 2 RPC functions, RLS policies, indexes, dropping old tables), a new `word_quiz` feature folder with domain/data/application/presentation layers, offline support via `LocalStorage`, and routing updates to swap the old practice screen for the new quiz home. The feature uses spaced repetition (3 correct answers on non-consecutive days) enforced server-side.

## Stages

### Stage 1: Database Migration
**Goal:** Create all database objects and drop old tables so the backend is ready for the feature.
**Files to create/modify:**
- `supabase/migrations/{timestamp}_word_quiz.sql` — full migration file

**Steps:**
- [x] Generate migration file via `supabase migration new word_quiz`
- [x] Add `DROP TABLE IF EXISTS public.practice_attempts; DROP TABLE IF EXISTS public.practice_questions;` to remove old tables
- [x] Create `daily_words` table (id uuid PK default gen_random_uuid(), word_en text NOT NULL, word_ru text NOT NULL, created_at timestamptz default now())
- [x] Create `daily_word_sets` table (id uuid PK default gen_random_uuid(), word_id uuid FK → daily_words NOT NULL, active_date date NOT NULL, created_at timestamptz default now()); add index on `active_date`
- [x] Create `word_quiz_attempts` table (id uuid PK default gen_random_uuid(), user_id uuid FK → auth.users NOT NULL default auth.uid(), word_id uuid FK → daily_words NOT NULL, selected_option text NOT NULL, is_correct boolean NOT NULL, language_direction text NOT NULL CHECK (language_direction IN ('en_to_ru', 'ru_to_en')), answered_at timestamptz default now()); add indexes on `(user_id, answered_at)` and `(user_id, word_id, language_direction)`
- [x] Create `word_learning_progress` table (id uuid PK default gen_random_uuid(), user_id uuid FK → auth.users NOT NULL default auth.uid(), word_id uuid FK → daily_words NOT NULL, correct_count int default 0, last_correct_date date, learned_at timestamptz, dates_correct jsonb default '[]'::jsonb, created_at timestamptz default now(), updated_at timestamptz default now()); add UNIQUE constraint on `(user_id, word_id)`
- [x] Enable RLS on all 4 tables; create policies: `daily_words` and `daily_word_sets` — SELECT for authenticated; `word_quiz_attempts` — SELECT/INSERT own rows; `word_learning_progress` — SELECT/INSERT/UPDATE own rows
- [x] Create `get_todays_words()` RPC: compute quiz day as `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date`, return `daily_words.*` joined with `daily_word_sets` where `active_date` matches
- [x] Create `upsert_word_learning_progress(p_word_id uuid, p_correct_date date)` RPC: insert or update row for current user + word; merge `p_correct_date` into `dates_correct` JSONB array with deduplication; increment `correct_count`; update `last_correct_date`; run learned-check algorithm (sort dates, greedily chain dates with 1–3 day gaps, mark learned if 3 chained); set `learned_at` if newly learned; update `updated_at`

**Verification:** Run `supabase db reset` locally. Verify old tables are gone, new tables exist, RPC functions are callable, and RLS blocks cross-user access.

### Stage 2: Domain Models & Repository
**Goal:** Create the domain layer and data layer for the word quiz feature, including Supabase integration and local cache/offline queue.
**Files to create/modify:**
- `lib/src/features/word_quiz/domain/daily_word.dart` — DailyWord model
- `lib/src/features/word_quiz/domain/word_quiz_attempt.dart` — WordQuizAttempt model
- `lib/src/features/word_quiz/domain/word_learning_progress.dart` — WordLearningProgress model
- `lib/src/features/word_quiz/domain/quiz_session.dart` — QuizSession model (tracks current session state)
- `lib/src/features/word_quiz/data/word_quiz_repository.dart` — repository with Supabase + local cache

**Steps:**
- [x] Create `DailyWord` immutable class (id, wordEn, wordRu) with `fromJson` factory
- [x] Create `WordQuizAttempt` immutable class (id, userId, wordId, selectedOption, isCorrect, languageDirection, answeredAt) with `toJson` for insert
- [x] Create `WordLearningProgress` immutable class (id, userId, wordId, correctCount, lastCorrectDate, learnedAt, datesCorrect)
- [x] Create `QuizSession` immutable class with `copyWith` — holds: todayWords (list of DailyWord), answeredWordIds (set of String), attempts (list of WordQuizAttempt), quizDay (DateTime), languageDirection (enum: enToRu, ruToEn)
- [x] Create `WordQuizRepository` (`@Riverpod(keepAlive: true)`) with methods: `fetchTodaysWords()` (calls `get_todays_words` RPC), `fetchAllWords()` (selects all from `daily_words`), `fetchTodayAttempts(languageDirection)` (queries `word_quiz_attempts` for user + today), `saveAttempt(WordQuizAttempt)` (inserts to `word_quiz_attempts`), `updateLearningProgress(wordId, correctDate)` (calls `upsert_word_learning_progress` RPC)
- [x] Add local cache layer in repository: cache today's words in `LocalStorage` keyed by quiz day; store pending (failed) attempts in `LocalStorage`; flush pending attempts on `fetchTodaysWords()` call (opportunistic sync)

**Verification:** Write a manual test or use Supabase local dashboard to insert seed words into `daily_words` + `daily_word_sets` for today's date, then call repository methods from a test provider and verify data flows correctly.

### Stage 3: Quiz State Management (Provider)
**Goal:** Create the application-layer notifier that orchestrates quiz flow: loading words, generating options, tracking progress, saving attempts, and handling offline queue.
**Files to create/modify:**
- `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — main quiz state controller
- `lib/src/features/word_quiz/application/quiz_home_notifier.dart` — quiz home screen state (progress, completion)

**Steps:**
- [x] Create `WordQuizNotifier` (`@riverpod` class, auto-dispose) managing `AsyncValue<QuizSession>`: `build()` loads today's words via repository, loads today's attempts for current direction, restores answered word IDs from local cache, and resumes session
- [x] Implement `generateOptions(DailyWord word)` helper: 1 correct answer + 3 random distractors from today's set (fall back to full `daily_words` pool if fewer than 4 in today's set); shuffle options; return as list of strings based on language direction
- [x] Implement `submitAnswer(String wordId, String selectedOption, bool isCorrect)`: save attempt to Supabase (queue locally on failure), update answered word IDs in local cache, call `upsert_word_learning_progress` RPC if correct, advance to next word or mark session finished
- [x] Implement `switchDirection(LanguageDirection)`: persist direction in `LocalStorage`, clear local session state (answered IDs), reload attempts for new direction
- [x] Create `QuizHomeNotifier` (`@riverpod` class, auto-dispose) that exposes: today's completed count (filtered by direction), total words count, whether quiz is finished, and quiz results (score + mistakes list)
- [x] Handle day boundary: compare cached quiz day with computed `getQuizDay()`, re-fetch if stale

**Verification:** Hot-reload the app, verify provider logs show correct word loading, option generation produces 4 unique options, and direction switch clears session state.

### Stage 4: Quiz Home Screen
**Goal:** Build the quiz entry point screen that shows progress, language selector, and start/continue button, replacing the old Practice tab.
**Files to create/modify:**
- `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` — quiz home screen
- `lib/src/features/word_quiz/presentation/quiz_completion_view.dart` — completion state (score + mistakes)
- `lib/src/routing/app_router.dart` — update import and route target
- `lib/src/routing/scaffold_with_nav.dart` — no changes needed (tab label and path stay the same)

**Steps:**
- [x] Create `WordQuizHomeScreen` (ConsumerWidget): shows language pair display ("English → Русский") with a swap button that calls `switchDirection`, progress bar with "5/20 words completed" text, and "Start Quiz" / "Continue Quiz" button based on progress
- [x] Create `QuizCompletionView` widget: shown when all words are done; displays score ("16/20"), encouraging message based on score range (nice-to-have from spec), and list of mistakes (word, user answer, correct answer); "Done" button returns to quiz home state
- [x] Handle empty state: "No words available for today. Check back tomorrow!" when no words returned
- [x] Update `app_router.dart`: change the `/practice` route to point to `WordQuizHomeScreen`; update import from `practice_screen.dart` to `word_quiz_home_screen.dart`; keep `AppRoute.practice` enum value and `/practice` path unchanged

**Verification:** Run the app, tap "Practice" in bottom nav, verify quiz home screen loads showing today's progress (0/N if no attempts yet), language selector toggles direction, and empty state shows when no words are seeded.

### Stage 5: Quiz Play Screen
**Goal:** Build the question-by-question quiz screen with multiple choice, feedback, and auto-advance.
**Files to create/modify:**
- `lib/src/features/word_quiz/presentation/word_quiz_screen.dart` — main quiz gameplay screen
- `lib/src/features/word_quiz/presentation/quiz_option_button.dart` — answer option button with correct/wrong states

**Steps:**
- [x] Create `WordQuizScreen` (ConsumerStatefulWidget): shows current word in source language at top, progress indicator ("7/20"), and 4 option buttons; navigated to from quiz home's "Start/Continue" button
- [x] Create `QuizOptionButton` widget with states: idle, correct (green highlight), wrong (red highlight + green on correct), dimmed; use `AnimatedContainer` for color transitions (nice-to-have animation)
- [x] On option tap: call `submitAnswer` on the notifier, show feedback state, auto-advance after ~1s (correct) or ~1.5s (wrong) using a `Future.delayed` + mounted check
- [x] After last word answered: navigate to completion view (or pop back to quiz home which shows completion state)
- [x] Ensure no word repeats: the notifier serves words from the unanswered pool only

**Verification:** Play through a full quiz session — verify each word appears once, feedback displays correctly, auto-advance works, and results screen shows accurate score and mistakes.

### Stage 6: Cleanup & Polish
**Goal:** Remove old practice feature, clean up dangling references, ensure offline support works, and verify everything passes analysis.
**Files to create/modify:**
- `lib/src/features/practice/` — delete entire directory
- `lib/src/features/word_quiz/domain/quiz_day_util.dart` — timezone utility (if not already extracted)
- Various files — remove any dangling practice imports/references

**Steps:**
- [x] Delete `lib/src/features/practice/` directory entirely
- [x] Search for and remove any remaining imports of practice feature files across the codebase
- [x] Verify home and profile screens gracefully handle absence of practice XP state (both are currently mock-only, so likely no changes needed — just confirm)
- [x] Verify the `chat_messages.context_source` check constraint in the DB — if it includes 'practice', the word quiz feature can reuse that value or it can be left as-is since it's not used by this feature
- [ ] Test offline flow: load quiz with network, toggle airplane mode, play through quiz, come back online, verify attempts sync on next app foreground / quiz start
- [x] Run `flutter analyze` and fix any errors
- [x] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate all codegen files

**Verification:** `flutter analyze` passes with no errors. App runs end-to-end: quiz home → play quiz → results → quiz home shows completion. Offline cache works. No references to old practice feature remain.

## Supabase Changes

### New Tables
- `daily_words` — admin-managed word pool (word_en, word_ru)
- `daily_word_sets` — maps words to active dates (word_id, active_date)
- `word_quiz_attempts` — user answer log (user_id, word_id, selected_option, is_correct, language_direction, answered_at)
- `word_learning_progress` — spaced repetition tracking (user_id, word_id, correct_count, dates_correct JSONB, learned_at)

### Dropped Tables
- `practice_questions`
- `practice_attempts`

### RPC Functions
- `get_todays_words()` — returns today's word set using Almaty timezone day boundary
- `upsert_word_learning_progress(p_word_id, p_correct_date)` — server-side merge of correct dates with learned-check algorithm

### Indexes
- `daily_word_sets(active_date)`
- `word_quiz_attempts(user_id, answered_at)`
- `word_quiz_attempts(user_id, word_id, language_direction)`
- `word_learning_progress(user_id, word_id)` — unique constraint

### RLS Policies
- `daily_words`: SELECT for authenticated users
- `daily_word_sets`: SELECT for authenticated users
- `word_quiz_attempts`: SELECT/INSERT for own rows (user_id = auth.uid())
- `word_learning_progress`: SELECT/INSERT/UPDATE for own rows (user_id = auth.uid())

## Test Coverage

- **Repository unit tests:** Mock Supabase client, verify `fetchTodaysWords`, `saveAttempt`, `updateLearningProgress` produce correct queries and handle errors
- **Notifier unit tests:** Override repository with mock, verify: option generation produces 4 unique choices, answered words don't repeat, session progress persists across restarts, direction switch resets session
- **Learned-check algorithm:** Test the SQL function with various date arrays — valid sequences (3 days with 1–3 gaps), invalid sequences (gaps > 3), duplicates, fewer than 3 dates
- **Offline queue:** Verify pending attempts are stored locally when Supabase insert fails, and flushed on next sync opportunity
- **Day boundary:** Verify `getQuizDay()` returns correct date at various UTC times around the 21:00 UTC (02:00 Almaty) boundary

## Risks

- **No seed data tooling:** Words must be manually inserted into `daily_words` and `daily_word_sets` via Supabase dashboard. If no words exist for today, users see an empty state. Consider adding a small seed data set in the migration for development/testing.
- **Almaty timezone hardcoded as UTC+5:** If Kazakhstan changes its UTC offset (unlikely but last changed in 2004), the client and server calculations will diverge until updated. Risk accepted per spec.
- **`chat_messages.context_source` CHECK constraint** includes 'practice' — this is unrelated to the word quiz feature but should not cause issues since the constraint is on allowed values, not required ones. If future work wants a 'word_quiz' context source, a migration will be needed.
- **Migration drops tables:** `practice_attempts` and `practice_questions` are dropped. Any manually-inserted seed data in those tables will be lost. This is intentional per spec since the old practice feature is being fully replaced.

## Out of Scope

- XP system integration (no XP earned from word quiz)
- Daily goals integration
- Push notifications / reminders
- Statistics / progress dashboard for learned words
- Weekly/monthly big quiz (100 words)
- Admin UI for managing words
- Leaderboards or social features
- Audio pronunciation
- Word categories or difficulty levels
- Real-time connectivity listening (`connectivity_plus` package)
