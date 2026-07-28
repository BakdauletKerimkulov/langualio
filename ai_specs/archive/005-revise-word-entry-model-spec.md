# Spec: Revise WordEntry Model — Multi-Meaning Support

Created: 2026-06-06
Status: refined
Refined: 2026-06-06
Source request: На данный момент в приложении только одна модель WordEntry которая описывает слово и перевод и тип слова. Но часто бывает так что одно слово имеет несколько переводов, и оно может быть как noun так и verb. Надо переосмыслить и сделать эталонное решение. Затем исправить участки которые затронет эта модель, например admin где используется map а не модель.

## Goal

Restructure `WordEntry` so that a single word can carry multiple meanings — each with its own part of speech, translations, definitions, and example sentences. Migrate the admin panel from untyped `Map<String, dynamic>` to the typed model. Update the Edge Function to generate the new structure.

## Background

**Stack & conventions:** Flutter + Riverpod (code-gen), Supabase (PostgreSQL + Edge Functions), freezed for domain models, feature-first architecture. Domain models live in `domain/`, repositories in `data/`, controllers in `application/`. Domain is pure Dart — no Firebase/Supabase imports. DTOs handle serialization in `data/` layer. See `ai_toolkit/guidelines/architecture.md` (lines 6–28, 78–126, 129–159) and `ai_toolkit/guidelines/code-style.md` (lines 143, 148–171).

**Project context:** `WordEntry` (`lib/src/features/word_quiz/domain/word_entry.dart`) is a freezed model with 17 flat fields — one `partOfSpeech`, one `translation`, one pair of examples. The admin panel (`lib/src/features/admin/`) uses raw `Map<String, dynamic>` throughout its repository, notifier, and form screen. The Edge Function `generate-word-entry` (`supabase/functions/generate-word-entry/index.ts`) returns a flat JSON object matching the current schema. The DB table `daily_words` stores all fields as flat columns (migration `20260526120000_admin_panel.sql`).

**Why now:** Words like "run", "play", "set" have distinct meanings as different parts of speech. The current flat model forces admins to pick one translation and one POS, losing linguistic accuracy. The admin panel's use of raw maps is a maintenance risk that should be fixed alongside the model change.

## User Flow

### Happy path

1. **Admin creates a word:** Admin enters "run" in the generate field → Edge Function returns a `WordEntry` with `meanings: [{partOfSpeech: verb, translation: "бежать", ...}, {partOfSpeech: noun, translation: "пробежка", ...}]` → admin reviews typed form with expandable meaning sections → saves as draft or published.
2. **Admin edits a word:** Admin opens existing word → form loads `WordEntry` from repository (typed, not map) → admin adds/removes/edits meanings → saves.
3. **User takes quiz:** Quiz loads today's words → for each word with multiple meanings, one random meaning is selected for the session → user sees "run" once → correct answer is the translation of the selected meaning → user answers → progress tracked at word level.
4. **Word detail (future):** Word card could show all meanings — not in scope for this spec, but the data model supports it.

### Alternative flows

- If the Edge Function returns a word with only one meaning (e.g. "cat"), the model works identically — `meanings` list has one item.
- If admin deletes all meanings from a word, validation prevents saving (at least one meaning required).
- Per-meaning validation: each meaning must have non-empty `translation`, `exampleEn`, `exampleRu`, and a selected `partOfSpeech`. Duplicate POS across meanings is allowed (a word can have two noun meanings). Show inline field errors per meaning section.

### Error & recovery flows

- If the Edge Function fails to generate meanings, admin sees error and can retry or enter manually.
- If DB migration encounters words with NULL `part_of_speech` or `translation`, the migration provides sensible defaults.

### Edge cases

- **Empty meanings list:** Prevented by client-side validation (admin form) and DB constraint (JSONB `meanings` must be a non-empty array).
- **Legacy data:** Migration converts existing flat columns into a single-item `meanings` JSONB array.
- **Large number of meanings:** Practically capped at 5–6; no hard limit needed.
- **Quiz with single-meaning words:** Behaves identically to current behavior — the one meaning is always selected.

## Requirements

### Must Have

- [ ] R1: New `WordMeaning` model as a freezed class with fields: `partOfSpeech` (PartOfSpeech), `translation` (String), `alternativeTranslations` (List\<String\>), `definitionEn` (String?), `definitionRu` (String?), `exampleEn` (String), `exampleRu` (String). Verifiable by: unit test creates `WordMeaning`, checks all fields, `copyWith`, JSON round-trip.
- [ ] R2: `WordEntry` model restructured: remove flat `translation`, `partOfSpeech`, `alternativeTranslations`, `definitionEn`, `definitionRu`, `exampleEn`, `exampleRu` fields; add `meanings` (List\<WordMeaning\>). Keep `id`, `word`, `ipa`, `level`, `topic`, `tags`, `createdAt`, `updatedAt`, `status`, `createdBy`. Verifiable by: unit test creates `WordEntry` with multiple meanings, checks JSON round-trip, `fromJson`/`toJson`.
- [ ] R3: DB migration converts `daily_words` table: move `part_of_speech`, `translation`, `alternative_translations`, `definition_en`, `definition_ru`, `example_en`, `example_ru` into a JSONB `meanings` column. Existing rows are migrated by wrapping current values into a single-element array. Verifiable by: `supabase db reset` succeeds, existing data appears in `meanings[0]`.
- [ ] R4: `get_todays_words()` RPC returns rows with `meanings` JSONB included (the RPC uses `SELECT dw.*` so it auto-reflects schema changes — no RPC modification needed, only verification). `WordEntry.fromJson` deserializes correctly. Verifiable by: call RPC after migration, verify returned JSON includes `meanings` and excludes dropped columns.
- [ ] R5: `WordQuizRepository.fetchTodaysWords()` and `fetchAllWords()` return `List<WordEntry>` with populated `meanings`. Verifiable by: integration test fetches words, asserts `meanings.isNotEmpty`.
- [ ] R6: `WordQuizNotifier.generateOptions(WordEntry word)` accepts an additional `meaningIndex` parameter (or the notifier picks a random meaning index per word at session start and stores it in `QuizSession`). The correct answer is derived from the selected meaning's `translation` (en→ru) or the word's `word` field (ru→en). Verifiable by: unit test with multi-meaning word, check correct answer matches selected meaning.
- [ ] R7: `QuizSession` stores a `Map<String, int> selectedMeaningIndexes` mapping `wordId` → meaning index (randomly chosen at session creation). Note: `QuizSession` is a hand-written immutable class (not freezed) — update its constructor, `copyWith`, and `operator ==`/`hashCode` manually. `selectedMeaningIndexes` should NOT be part of equality (it's randomized per session). Verifiable by: unit test creates session with multi-meaning words, checks each word has a valid meaning index.
- [ ] R8: `WordQuizScreen` uses the selected meaning index to determine `questionWord` and `correctAnswer`. Verifiable by: manual QA — quiz shows correct translation for the selected meaning.
- [ ] R9: `AdminRepository` methods (`generateWordEntry`, `createWord`, `fetchWords`, `fetchWordById`, `updateWord`) accept and return `WordEntry` instead of `Map<String, dynamic>`. Verifiable by: compile succeeds, admin CRUD flow works end-to-end.
- [ ] R10: `AdminWordFormNotifier` state uses `WordEntry?` instead of `Map<String, dynamic>?` for `generatedData`. Methods `save` and `update` accept `WordEntry`. Verifiable by: compile succeeds, admin form generates/saves/updates words.
- [ ] R11: `AdminWordFormScreen` and `WordFormFields` render meanings as an expandable list — each meaning section has its own POS dropdown, translation, definitions, examples. Admin can add/remove meanings. Verifiable by: manual QA — add word with 2 meanings, save, reload, verify both meanings present.
- [ ] R12: Edge Function `generate-word-entry` updated: system prompt requests a `meanings` array; response is parsed as new structure. Verifiable by: `curl` the function with "run" → response has `meanings` array with 2+ items.
- [ ] R13: `WordEntriesTable` (Drift local cache) updated to store `meanings` as a JSON text column. `toModel()` and `toCompanion()` extensions handle serialization. Verifiable by: unit test round-trips a `WordEntry` through Drift.
- [ ] R14: Local cache in `WordQuizRepository` (`getCachedTodaysWords`) correctly serializes/deserializes the new `meanings` field. Verifiable by: cache a multi-meaning word, retrieve it, assert meanings intact.

### Nice to Have

- [ ] N1: Convenience getters on `WordEntry`: `String get primaryTranslation => meanings.first.translation`, `PartOfSpeech get primaryPartOfSpeech => meanings.first.partOfSpeech`. Useful for displays that need a single value.
- [ ] N2: Admin form auto-generates additional meanings: after initial generation, admin can click "Generate more meanings" to call the Edge Function again for the same word with instruction to produce only missing POS meanings.

### Non-functional

- Performance: Quiz session creation (selecting random meanings) must complete in <10ms for 20 words.
- Accessibility: Admin form meaning sections must be keyboard-navigable; each section has a clear label.

## Technical Constraints

**Files to create:**
- `lib/src/features/word_quiz/domain/word_meaning.dart` — new freezed model for `WordMeaning`
- `lib/src/features/word_quiz/domain/part_of_speech.dart` — extracted `PartOfSpeech` enum (currently defined inline in `word_entry.dart:6-16`; must be in its own file so `WordMeaning` can import it without depending on `WordEntry`)
- `supabase/migrations/{next_timestamp}_word_meanings_jsonb.sql` — DB migration

**Files to modify:**
- `lib/src/features/word_quiz/domain/word_entry.dart` — remove flat meaning fields, add `List<WordMeaning> meanings`
- `lib/src/features/word_quiz/domain/quiz_session.dart` — add `Map<String, int> selectedMeaningIndexes`
- `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — select random meaning per word, update `generateOptions`
- `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart` — update deserialization, cache format
- `lib/src/features/word_quiz/data/local/word_entries_table.dart` — replace flat columns with `meanings` JSON column
- `lib/src/features/word_quiz/presentation/word_quiz_screen.dart` — use selected meaning for question/answer
- `lib/src/features/admin/data/admin_repository.dart` — return `WordEntry` instead of `Map`
- `lib/src/features/admin/application/admin_word_form_notifier.dart` — state uses `WordEntry?`, methods accept `WordEntry`
- `lib/src/features/admin/presentation/admin_word_form_screen.dart` — render meanings list, manage meaning controllers
- `lib/src/features/admin/presentation/widgets/word_form_fields.dart` — refactor to render per-meaning fields
- `lib/src/features/admin/presentation/widgets/word_list_tile.dart` — display primary meaning info
- `supabase/functions/generate-word-entry/index.ts` — update system prompt and response parsing
- `lib/src/features/word_quiz/domain/word_entry.dart` — also: remove inline `PartOfSpeech` enum (moved to its own file), update import

**Patterns to follow (with citations):**
- Follow the freezed model pattern in `ai_toolkit/guidelines/architecture.md` (lines 299–324) for `WordMeaning`.
- Follow the repository pattern in `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart` for typed returns.
- Follow the controller pattern in `lib/src/features/word_quiz/application/word_quiz_notifier.dart` (lines 15–16, 22–70) for session initialization with random meaning selection.

**Anti-patterns / avoid:**
- Do not store meanings in a separate DB table — use JSONB column on `daily_words` to avoid join complexity.
- Do not create a separate DTO class for `WordMeaning` — the model is simple enough to use `fromJson`/`toJson` directly via freezed. (Note: this follows the existing `WordEntry` pattern, which also has `fromJson` on the domain model rather than using a separate DTO. This is an acknowledged deviation from the DTO guideline in `architecture.md:129-159`, kept for pragmatism.)
- Do not change the `word_quiz_attempts` or `word_learning_progress` tables — progress stays at word level.

**Data layer changes:**
- New migration adds `meanings JSONB NOT NULL` column to `daily_words` (no DEFAULT — the app always provides meanings on insert; a DEFAULT of `'[]'` would contradict the non-empty array constraint).
- Migration populates `meanings` from existing flat columns for all rows.
- Migration drops the old flat columns (`translation`, `part_of_speech`, `alternative_translations`, `definition_en`, `definition_ru`, `example_en`, `example_ru`).
- `get_todays_words()` RPC updated to return `meanings` in the result.
- RLS policies unchanged — they filter on `status`, not on meaning content.

**JSON key format for meanings JSONB:**
- The JSONB `meanings` array must use camelCase keys matching Dart/freezed convention: `{"partOfSpeech": "verb", "translation": "...", ...}`. The Edge Function must output meanings with camelCase keys. The current flat columns use snake_case (e.g. `part_of_speech`), but since `meanings` is a new JSONB column parsed by freezed's `fromJson`, camelCase is correct. If snake_case is preferred for DB consistency, add `@JsonKey(name: 'part_of_speech')` annotations to the `WordMeaning` freezed model.

**External integrations:**
- Edge Function `generate-word-entry`: update Claude prompt to return `meanings` array with camelCase keys. No auth/rate-limit changes.

## Edge Cases

See User Flow > Edge cases above. Key additions:
- **Quiz distractor pool with meanings:** Distractors are drawn from `meanings.first.translation` (or a random meaning) of other words. The pool logic in `generateOptions` uses the same meaning-selection strategy.
- **Word with no published meanings:** Should not occur; DB constraint ensures `meanings` is non-empty. If it does, word is skipped in quiz.

## Out of Scope

- NOT adding per-meaning progress tracking — progress stays at word level (`word_learning_progress.word_id`), because tracking meaning-level mastery would overcomplicate the quiz and learning algorithm.
- NOT changing the quiz UI layout — the quiz screen shows one word and four options, same as today.
- NOT adding a "word detail" screen to show all meanings — this is a future feature.
- NOT touching `word_quiz_attempts` or `word_learning_progress` tables or their RPC functions. **Known limitation:** `WordQuizAttempt` does not store which meaning index was tested, so after a session ends, mistake review cannot show which specific meaning was the correct answer for multi-meaning words. This is acceptable for now; adding `meaning_index` to the attempts table is a future improvement.
- NOT adding i18n/localization — strings remain hardcoded Russian.
- NOT refactoring the admin panel's screen/widget structure beyond what's needed for meanings (e.g. not redesigning the word list).

## Validation

**Automated tests:**
- Unit: `WordMeaning` — creation, copyWith, JSON round-trip (`test/src/features/word_quiz/domain/word_meaning_test.dart`)
- Unit: `WordEntry` — creation with meanings list, JSON round-trip, convenience getters (`test/src/features/word_quiz/domain/word_entry_test.dart`)
- Unit: `QuizSession` — `selectedMeaningIndexes` population, `currentWord` still works (`test/src/features/word_quiz/domain/quiz_session_test.dart`)
- Unit: `WordQuizNotifier.generateOptions` — correct answer matches selected meaning for both language directions (`test/src/features/word_quiz/application/word_quiz_notifier_test.dart`)

**Manual QA scenarios:**
1. Given a fresh DB after migration, when querying `daily_words`, then existing words have `meanings` JSONB with one element containing the original data.
2. Given admin opens "New word" and generates "run", when Edge Function responds, then form shows 2+ meaning sections (verb + noun).
3. Given admin adds a third meaning to a word and saves as published, when reloading the word, then all 3 meanings are present.
4. Given quiz loads a word with 3 meanings, when the quiz starts, then the word appears once with a translation from one of its meanings.
5. Given quiz with en→ru direction and a multi-meaning word, when user selects the correct translation for the chosen meaning, then answer is marked correct.
6. Given quiz with ru→en direction, when a multi-meaning word appears, then the question shows the translation from the selected meaning and correct answer is the English word.

**Expected behavior under edge conditions:**
- Offline: Cached words include `meanings` JSONB → quiz works offline with correct meaning selection.
- Backend error on Edge Function: Admin sees error snackbar, can retry or enter manually.
- Empty data (new user, no words): Quiz shows empty state — unchanged behavior.

## Definition of Done

- [ ] All Must Have requirements pass automated tests
- [ ] All Manual QA scenarios pass on Android and iOS
- [ ] `supabase db reset` succeeds with new migration; existing data migrated correctly
- [ ] Edge Function deployed and returns `meanings` array
- [ ] No new lint warnings; matches `ai_toolkit/` style guide
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds
- [ ] Spec file linked in the PR description
