# Spec: Daily Word Quiz

Created: 2026-05-14
Status: refined

## Goal

Replace the existing Practice screen with a daily word quiz that helps users learn English-Russian vocabulary through spaced repetition. Each day, 20 words are available for practice. A word is considered "learned" only when the user guesses it correctly 3 times on different, non-consecutive days — enforcing real retention over short-term memorization.

## Background

The current Practice screen (`/practice`) has 3 hardcoded mock questions and no backend integration. It awards XP locally (10 XP per correct answer) but this is not persisted to the backend. This feature replaces it entirely with a production-ready daily quiz backed by Supabase. Words are manually curated and added to the database by the admin. The same 20 words are shown to all users each day, refreshing at 02:00 Almaty time (UTC+5).

**Note:** The current practice screen's XP earning flow is removed. XP integration for the word quiz is out of scope — any screens referencing practice XP (home, profile) should gracefully handle the absence.

## User Flow

1. User taps "Practice" in the bottom navigation bar.
2. **Quiz home screen** shows:
   - Language pair display (e.g., "English → Русский") with a swap button.
   - Today's progress: "5/20 words completed" with a progress bar.
   - "Continue Quiz" button (or "Start Quiz" if not started today).
   - If all 20 words are done today — show completion state with score and mistakes.
3. User taps "Start Quiz" / "Continue Quiz".
4. **Quiz screen** shows one word at a time:
   - The word in the source language (e.g., English) at the top.
   - 4 option buttons with translations in the target language (e.g., Russian).
   - Progress indicator: "7/20" at the top.
5. User taps an option:
   - **Correct:** brief positive feedback (green highlight), auto-advance after ~1s.
   - **Wrong:** brief negative feedback (red highlight on selected + green on correct), auto-advance after ~1.5s.
6. After all 20 words are answered:
   - **Results screen** shows:
     - Score: "16/20" with encouraging message.
     - List of mistakes: each mistake shows the word, user's wrong answer, and the correct answer.
     - "Done" button returns to quiz home.
7. User can change language direction at any time from the quiz home screen (swap source ↔ target). This resets current local session progress for the day since questions change. Previous attempts in the old direction remain as historical records in `word_quiz_attempts`.

## Requirements

### Must Have

- [ ] New DB table `daily_words`: stores the word pool (id, word_en, word_ru, created_at)
- [ ] New DB table `daily_word_sets`: maps which words are active on which date (id, word_id, active_date). 20 rows per date.
- [ ] New DB table `word_quiz_attempts`: tracks each answer (id, user_id, word_id, selected_option, is_correct, language_direction, answered_at)
- [ ] New DB table `word_learning_progress`: tracks learning state per user per word (id, user_id, word_id, correct_count, last_correct_date, learned_at, dates_correct JSONB array)
- [ ] Drop old `practice_questions` and `practice_attempts` tables in the migration (fully replaced by new tables)
- [ ] RLS policies: users can read `daily_words` and `daily_word_sets`; users can read/insert own `word_quiz_attempts`; users can read/insert/update own `word_learning_progress`
- [ ] Supabase RPC function `upsert_word_learning_progress(p_word_id, p_correct_date)`: merges the date into `dates_correct` server-side using `array_append` + deduplication, increments `correct_count`, updates `last_correct_date`, and runs the learned-check algorithm to set `learned_at` — avoids multi-device JSONB overwrite conflicts
- [ ] Supabase RPC function `get_todays_words()`: computes quiz day server-side using `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date` and returns today's words joined from `daily_word_sets` + `daily_words` — eliminates client-server date disagreements
- [ ] Quiz home screen replacing the current Practice tab in bottom nav
- [ ] Language direction selector (EN→RU or RU→EN) persisted locally via SharedPreferences
- [ ] Load today's words via `get_todays_words()` RPC; also load the full `daily_words` table for distractor generation (table is small, admin-managed)
- [ ] 4-option multiple choice: 1 correct + 3 random distractors from the day's word set (fall back to full `daily_words` pool if fewer than 4 words in today's set)
- [ ] Save each answer to `word_quiz_attempts` immediately; on failure, queue locally and sync on next app foreground or quiz start
- [ ] Progress persistence: if user closes app mid-quiz, resume from where they left off (track answered word IDs locally)
- [ ] After answering all 20 words, show results screen with score (e.g., "16/20") and list of mistakes
- [ ] Update `word_learning_progress` via `upsert_word_learning_progress` RPC on correct answer
- [ ] A word must NOT repeat within the same day's quiz session (each of 20 words appears exactly once)
- [ ] Day boundary is 02:00 Almaty time (UTC+5), i.e., the "quiz day" rolls over at 02:00 local Almaty
- [ ] Offline support: cache today's word set on first load; quiz is fully playable offline; sync pending attempts on next app foreground or quiz start (no real-time connectivity listening)
- [ ] "Completed words" query must filter by current `language_direction` to correctly track progress per direction

### Nice to Have

- [ ] Encouraging messages based on score range (e.g., 20/20: "Perfect!", 15-19: "Great job!", 10-14: "Good effort!", <10: "Keep practicing!")
- [ ] Simple animation on correct/wrong answer (color transition)
- [ ] Show "learned" badge on words in the results if they just reached learned status

## Technical Constraints

### Database

- New migration file: use `supabase migration new word_quiz` to generate timestamp-prefixed filename (e.g., `20260514XXXXXX_word_quiz.sql`), consistent with Supabase CLI conventions
- Drop old tables: `DROP TABLE IF EXISTS public.practice_attempts; DROP TABLE IF EXISTS public.practice_questions;` (fully replaced)
- `daily_words` table: admin-managed, no user writes
- `daily_word_sets` table: admin-managed, maps word_id to active_date
- `word_quiz_attempts` table: append-only per user
- `word_learning_progress` table: one row per user+word pair, updated via RPC function (not direct client upsert) to prevent multi-device JSONB conflicts
- All tables with RLS enabled
- Day boundary calculation: `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date` to handle the 02:00 rollover

#### Required Indexes

- `daily_word_sets(active_date)` — daily word lookup
- `word_quiz_attempts(user_id, answered_at)` — user's daily attempts query
- `word_learning_progress(user_id, word_id)` — unique constraint + lookup
- `word_quiz_attempts(user_id, word_id, language_direction)` — filtering completed words per direction

#### RPC Functions

- `get_todays_words()`: returns today's word set computed server-side with Almaty day boundary
- `upsert_word_learning_progress(p_word_id uuid, p_correct_date date)`: server-side merge of correct date into JSONB array, with deduplication, count increment, and learned-check — prevents data loss from concurrent multi-device updates

### Architecture

- New feature folder: `lib/src/features/word_quiz/` with domain/data/application/presentation layers
- Remove existing `lib/src/features/practice/` entirely
- Update `app_router.dart`: keep `AppRoute.practice` enum value and `/practice` path, point to new `WordQuizHomeScreen` — avoids unnecessary breaking changes
- Update `scaffold_with_nav.dart`: keep "Practice" tab label, point to new screen
- Update import in `app_router.dart`: replace `practice_screen.dart` import with `word_quiz_home_screen.dart`
- Verify and remove any references to practice XP state from other screens (home, profile)
- Domain models: `DailyWord`, `WordQuizAttempt`, `WordLearningProgress`, `QuizSession`
- Repository: `WordQuizRepository` with Supabase + local cache
- Provider: `@riverpod class WordQuizNotifier` managing quiz state
- Local cache: use `LocalStorage` (SharedPreferences) for today's word set, session progress, and language direction
- Offline queue: store pending attempts in SharedPreferences, flush to Supabase on app foreground or quiz start (no `connectivity_plus` dependency — sync is opportunistic, not event-driven)

### Timezone Handling

Almaty timezone is hardcoded as UTC+5 offset. No `package:timezone` dependency needed.

**Client-side utility:**
```dart
/// Returns the current quiz day date, accounting for 02:00 Almaty rollover.
/// Almaty = UTC+5. Quiz day rolls over at 02:00 Almaty (= 21:00 UTC previous day).
DateTime getQuizDay() {
  final nowUtc = DateTime.now().toUtc();
  final almatyTime = nowUtc.add(const Duration(hours: 5));
  final adjusted = almatyTime.subtract(const Duration(hours: 2));
  return DateTime(adjusted.year, adjusted.month, adjusted.day);
}
```

**Server-side (in SQL):** `(NOW() AT TIME ZONE 'Asia/Almaty' - INTERVAL '2 hours')::date`

**Risk accepted:** If Kazakhstan changes its UTC offset (last changed in 2004), the hardcoded +5 will need updating. This is an acceptable trade-off vs. adding a timezone package dependency.

### Spaced Repetition Logic (learned check)

A word is "learned" when `dates_correct` contains at least 3 dates where each consecutive pair has a gap of 1–3 days. Algorithm:
1. Sort `dates_correct` ascending.
2. Deduplicate dates.
3. Greedily walk the sorted dates: pick the first date, then find the next date that is 1–3 days after it, repeat.
4. If you can chain 3 such dates, the word is learned.

Example valid sequences: [Mon, Wed, Fri], [Mon, Thu, Sat]
Example invalid: [Mon, Tue, Wed] (gap=1 each — this IS valid since 1-day gap is allowed), [Mon, Fri, Mon] (gap=4, invalid)

Correction: gaps of 1–3 days means day differences of 1, 2, or 3. So [Mon, Tue, Wed] IS valid (gaps of 1). [Mon, Fri] is NOT valid (gap of 4).

**This algorithm runs server-side in the `upsert_word_learning_progress` RPC function**, not on the client, to ensure consistency.

## Edge Cases

- **No words for today:** Show empty state — "No words available for today. Check back tomorrow!"
- **Fewer than 20 words for today:** Show however many are available (quiz adapts to actual count)
- **Fewer than 4 words in the day's set:** Cannot generate 4 options — pull distractors from `daily_words` table (loaded in full alongside today's set, since the table is small)
- **User answers offline then goes online:** Queue attempts locally in SharedPreferences. Sync pending attempts on next app foreground or quiz start. Handle potential duplicate writes with `ON CONFLICT` upsert in the RPC function.
- **User changes language direction mid-day:** Clear local session state only (answered word IDs). Previous `word_quiz_attempts` rows with the old direction remain as historical records. "Completed words" is always filtered by current `language_direction`. Persist direction choice in SharedPreferences.
- **Same word appears in multiple days:** Expected behavior — the word keeps appearing until learned (or indefinitely since admin manages sets).
- **Date timezone edge case:** User's device timezone is irrelevant — client computes quiz day using hardcoded UTC+5 offset from `DateTime.now().toUtc()`. Server computes via `AT TIME ZONE 'Asia/Almaty'`.
- **App opened exactly at 02:00 Almaty:** Cached word set may be stale — compare cached date with computed quiz day, re-fetch if mismatched.
- **word_learning_progress dates_correct has duplicates:** RPC function deduplicates before running the learned-check algorithm.
- **Multi-device conflict:** `upsert_word_learning_progress` RPC merges dates server-side using `array_append` + deduplication, so concurrent updates from multiple devices don't overwrite each other's data.

## Out of Scope

- XP system integration (no XP earned from word quiz for now; the old practice XP flow is removed)
- Daily goals integration
- Push notifications / reminders
- Statistics / progress dashboard for learned words
- Weekly/monthly big quiz (100 words) — future feature
- Admin UI for managing words (done manually via Supabase dashboard)
- Leaderboards or social features
- Audio pronunciation
- Word categories or difficulty levels
- Real-time connectivity listening (`connectivity_plus` package) — offline sync is opportunistic

## Definition of Done

- [ ] Migration applied with all 4 new tables, 2 RPC functions, RLS policies, indexes, and old `practice_questions`/`practice_attempts` tables dropped
- [ ] `features/practice/` removed, `features/word_quiz/` created with full layer structure
- [ ] No dangling references to old practice XP state in other screens
- [ ] Quiz home screen shows today's progress, language selector, and start/continue button
- [ ] Quiz plays through all daily words with 4-option multiple choice
- [ ] Correct/wrong feedback displayed per question
- [ ] Results screen shows score and mistake list after completion
- [ ] Progress persists across app restarts (resume mid-quiz)
- [ ] Language direction persisted and switchable; switching resets local session, filters attempts by direction
- [ ] Spaced repetition logic correctly marks words as learned via server-side RPC (3 correct on different days with 1–3 day gaps)
- [ ] Offline mode works: cached words, local attempt storage, sync on app foreground/quiz start
- [ ] Day boundary at 02:00 Almaty time works correctly (client UTC+5 offset, server `AT TIME ZONE`)
- [ ] No word repeats within the same day's quiz
- [ ] All code follows project guidelines (Riverpod codegen, architecture layers, code style)
- [ ] `flutter analyze` passes with no errors
