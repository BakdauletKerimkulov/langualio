# Plan: Revise WordEntry Model — Multi-Meaning Support

Source: `ai_specs/005-revise-word-entry-model-spec.md`
Created: 2026-06-06
Status: implementation complete — manual QA pending

## Overview
Restructure `WordEntry` from flat single-meaning fields to a `meanings: List<WordMeaning>` model. Migrate DB column from flat fields to JSONB array. Update Edge Function, admin panel (Map → typed model), quiz logic (random meaning selection per session), and Drift local cache.

**Spec:** `ai_specs/005-revise-word-entry-model-spec.md`

## Context
- **Structure:** feature-first (`lib/src/features/{name}/domain|data|application|presentation`)
- **State management:** Riverpod code-gen (`@riverpod`), cited: `lib/src/features/word_quiz/application/word_quiz_notifier.dart`
- **Reference implementations:** `WordEntry` freezed model (`lib/src/features/word_quiz/domain/word_entry.dart`), `AdminRepository` (`lib/src/features/admin/data/admin_repository.dart`), `WordQuizRepository` (`lib/src/features/word_quiz/data/remote/word_quiz_repository.dart`)
- **Testing convention:** test structure mirrors `lib/`, group-based, domain model unit tests (`ai_toolkit/guidelines/architecture.md:536-572`)
- **Lint + test command:** `flutter analyze && flutter test`
- **Assumptions / Gaps:**
  - Spec says JSON keys in `meanings` JSONB should use camelCase for freezed compatibility. The Edge Function currently returns snake_case. Decision: use snake_case in DB JSONB + `@JsonKey` annotations on `WordMeaning` for consistency with DB conventions, as the spec allows this option.
  - `get_todays_words()` RPC uses `SELECT dw.*` — auto-reflects schema changes. Need to verify after migration, not modify the RPC.
  - No existing tests for word_quiz domain models — all tests are new.

## Plan

### Phase 1 — Domain models + DB migration (thin vertical slice)
**Goal:** New `WordMeaning` model, restructured `WordEntry`, DB migration. Prove the data layer compiles and serializes correctly.

- [x] TDD: `WordMeaning` creation, `copyWith`, JSON round-trip with snake_case keys → `test/src/features/word_quiz/domain/word_meaning_test.dart`
- [x] `lib/src/features/word_quiz/domain/part_of_speech.dart` — extract `PartOfSpeech` enum from `word_entry.dart` into own file
- [x] `lib/src/features/word_quiz/domain/word_meaning.dart` — new freezed model: `partOfSpeech`, `translation`, `alternativeTranslations`, `definitionEn?`, `definitionRu?`, `exampleEn`, `exampleRu` (no `@JsonKey` needed — `build.yaml` has `field_rename: snake` globally)
- [x] TDD: `WordEntry` with `meanings` list, JSON round-trip, convenience getters (`primaryTranslation`, `primaryPartOfSpeech`) → `test/src/features/word_quiz/domain/word_entry_test.dart`
- [x] `lib/src/features/word_quiz/domain/word_entry.dart` — remove flat meaning fields, add `List<WordMeaning> meanings`, import `PartOfSpeech` from new file, add convenience getters (N1)
- [x] `supabase/migrations/20260606120000_word_meanings_jsonb.sql` — add `meanings` JSONB column, populate from flat columns, drop old columns, add NOT NULL + non-empty array check constraint
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze`

### Phase 2 — Quiz logic (QuizSession + notifier)
**Goal:** Quiz correctly selects a random meaning per word and derives correct answer from it.

- [x] TDD: `QuizSession` with `selectedMeaningIndexes`, `currentWord` still works → `test/src/features/word_quiz/domain/quiz_session_test.dart`
- [x] `lib/src/features/word_quiz/domain/quiz_session.dart` — add `Map<String, int> selectedMeaningIndexes`, update `copyWith`, exclude from `==`/`hashCode`
- [x] TDD: `WordQuizNotifier.generateOptions` correct answer matches selected meaning for both directions → `test/src/features/word_quiz/application/word_quiz_notifier_test.dart`
- [x] `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — in `build()`, assign random meaning index per word; update `generateOptions` to use selected meaning's translation; update distractor pool to use `primaryTranslation`
- [x] `lib/src/features/word_quiz/presentation/word_quiz_screen.dart` — use `selectedMeaningIndexes` to derive `questionWord` and `correctAnswer` from the selected meaning
- [x] Verify: `flutter analyze && flutter test`

### Phase 3 — Data layer (repository + local cache)
**Goal:** Repository and Drift cache correctly handle the new `meanings` JSONB field.

- [x] `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart` — update `getCachedTodaysWords` cache serialization to include full `meanings` data (already implemented in Phase 1 — uses `w.toJson()`)
- [x] `lib/src/features/word_quiz/data/local/word_entries_table.dart` — replace flat meaning columns with single `meanings` TEXT column (JSON), update `toModel()` and `toCompanion()` extensions (already implemented in Phase 1)
- [x] `lib/src/features/word_quiz/data/local/local_word_quiz_repo.dart` — no references to removed flat fields, no changes needed
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`

### Phase 4 — Admin panel (Map → typed model)
**Goal:** Admin repository, notifier, and form use `WordEntry` instead of `Map<String, dynamic>`. Form renders expandable meaning sections.

- [x] `lib/src/features/admin/data/admin_repository.dart` — `generateWordEntry` returns `WordEntry`, `createWord`/`updateWord` accept `WordEntry`, `fetchWords`/`fetchWordById` return `WordEntry`/`List<WordEntry>`
- [x] `lib/src/features/admin/application/admin_word_form_notifier.dart` — `generatedData` becomes `WordEntry?`, `save`/`update` accept `WordEntry`
- [x] `lib/src/features/admin/presentation/admin_word_form_screen.dart` — manage list of meaning controllers (add/remove), populate from `WordEntry`, collect `WordEntry` from form; validation: at least one meaning with required fields
- [x] `lib/src/features/admin/presentation/widgets/word_form_fields.dart` — refactor to render per-meaning expandable sections (POS dropdown, translation, definitions, examples per meaning)
- [x] `lib/src/features/admin/presentation/widgets/word_list_tile.dart` — accept `WordEntry` instead of `Map`, display `primaryTranslation` and `primaryPartOfSpeech`
- [x] `lib/src/features/admin/application/admin_word_list_notifier.dart` — update state type if it uses `Map<String, dynamic>`
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`

### Phase 5 — Edge Function update
**Goal:** Edge Function returns `meanings` array structure.

- [x] `supabase/functions/generate-word-entry/index.ts` — update `SYSTEM_PROMPT` to request `meanings` array with multiple meanings per word (each with `part_of_speech`, `translation`, `alternative_translations`, `definition_en`, `definition_ru`, `example_en`, `example_ru`); parse response as new structure; keep top-level `word`, `ipa`, `level`, `topic`, `tags`
- [ ] Manual QA: `curl` the function with "run" → verify response has `meanings` array with 2+ items _blocked: requires supabase functions serve with Docker + env vars — manual step_
- [ ] Verify: `supabase functions serve` starts without errors _blocked: requires Docker running locally — manual step_

### Phase 6 — Integration verification
**Goal:** Full end-to-end validation.

- [ ] `supabase db reset` — verify migration succeeds, existing data appears in `meanings[0]` _blocked: requires Docker + local Supabase — manual step_
- [ ] Manual QA: admin create word with 2+ meanings, save, reload, verify persistence _blocked: requires running app + Supabase — manual step_
- [ ] Manual QA: quiz with multi-meaning word — word appears once, correct answer matches selected meaning _blocked: requires running app + Supabase — manual step_
- [x] Verify: `flutter analyze && flutter test`

## Data layer changes
- New migration: add `meanings JSONB NOT NULL` to `daily_words`
- Populate from existing flat columns: `[{"part_of_speech": ..., "translation": ..., "alternative_translations": ..., "definition_en": ..., "definition_ru": ..., "example_en": ..., "example_ru": ...}]`
- Drop flat columns: `translation`, `part_of_speech`, `alternative_translations`, `definition_en`, `definition_ru`, `example_en`, `example_ru`
- CHECK constraint: `jsonb_array_length(meanings) > 0`
- `get_todays_words()` RPC unchanged — `SELECT dw.*` auto-includes `meanings`

## External integrations
- Edge Function `generate-word-entry`: update Claude prompt to return `meanings` array. No auth/rate-limit changes.

## Risks
- **DB migration on production data:** Test with `supabase db reset` first; migration wraps existing data, so no data loss. Consider backing up before applying to remote.
- **Freezed JSON key format mismatch:** DB JSONB uses snake_case, freezed defaults to camelCase. Mitigated with `@JsonKey(name: ...)` annotations on `WordMeaning`.
- **Admin form complexity:** Multi-meaning form is significantly more complex than current flat form. Keep it simple — expandable sections, one at a time.
- **Edge Function prompt reliability:** Claude may return varying numbers of meanings. Add validation that `meanings` is a non-empty array in the Edge Function before returning.

## Out of scope
- Per-meaning progress tracking — progress stays at word level (`word_learning_progress.word_id`)
- Changing quiz UI layout — one word, four options, same as today
- "Word detail" screen showing all meanings — future feature
- Touching `word_quiz_attempts` or `word_learning_progress` tables/RPCs
- i18n/localization — strings remain hardcoded Russian
- Redesigning admin panel structure beyond meanings support
