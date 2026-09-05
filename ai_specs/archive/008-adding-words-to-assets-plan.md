# Plan: Bundle B1 Vocabulary as Local Asset

Source: `ai_specs/008-adding-words-to-assets-spec.md`
Created: 2026-06-14
Status: draft

## Overview
Bundle ~2000 B1 words as a JSON asset so quizzes work offline from first launch. Make `createdAt` nullable on `WordEntry` and Drift schema, create `AssetWordRepository` to load the JSON, and integrate asset words as fallback/base pool in `WordQuizNotifier`.

**Spec:** `ai_specs/008-adding-words-to-assets-spec.md`

## Context
- **Structure:** feature-first (`domain/data/application/presentation`), see `lib/src/features/word_quiz/`
- **State management:** Riverpod codegen (`@riverpod`), see `lib/src/features/word_quiz/application/word_quiz_notifier.dart`
- **Reference implementations:** `WordQuizRepository` (`lib/src/features/word_quiz/data/remote/word_quiz_repository.dart:18-189`) — repository + `@Riverpod(keepAlive: true)` provider pattern
- **Testing convention:** `flutter_test`, `group()` per class, test mirrors `lib/` structure. See `test/src/features/word_quiz/domain/word_entry_test.dart`
- **Lint + test command:** `dart analyze && flutter test`
- **JSON config:** `build.yaml` uses `field_rename: snake` + `explicit_to_json: true`
- **Assumptions / Gaps:** none — spec is thorough

## Plan

### Phase 1 — Thin vertical slice: nullable `createdAt` + asset loading
**Goal:** `WordEntry` accepts `createdAt: null`, asset JSON loads into typed models, Drift schema migrates.

- [x] `lib/src/features/word_quiz/domain/word_entry.dart:22` — change `required DateTime createdAt` → `DateTime? createdAt`
- [x] `lib/src/features/word_quiz/data/local/word_entries_table.dart:17` — change `dateTime()()` → `dateTime().nullable()()` for `createdAt`; update `toModel()` (line 40) and `toCompanion()` (line 57) for nullable `createdAt`
- [x] `lib/src/core/local_storage/drift.dart:24` — bump `schemaVersion` to 2; add `MigrationStrategy` to drop/recreate `WordEntriesTable` on upgrade
- [x] TDD: `WordEntry` with `createdAt: null` round-trips JSON correctly → then update existing test in `test/src/features/word_quiz/domain/word_entry_test.dart`
- [x] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `.freezed.dart`, `.g.dart`, Drift files
- [x] Verify: `dart analyze && flutter test`

### Phase 2 — Asset repository + placeholder JSON
**Goal:** `AssetWordRepository` loads `b1_words.json` into `List<WordEntry>`, exposed via `keepAlive` provider.

- [x] `assets/data/b1_words.json` — create placeholder with 5 sample B1 words matching the spec schema (`b1_ability`, etc.)
- [x] `pubspec.yaml:40` — add `assets:` section with `- assets/data/`
- [x] `lib/src/features/word_quiz/data/local/asset_word_repository.dart` — create `AssetWordRepository` (loads + parses `b1_words.json` via `rootBundle`) and `assetWordsProvider` (`@Riverpod(keepAlive: true)`)
- [x] TDD: `AssetWordRepository` loads sample JSON and returns correctly typed `List<WordEntry>` → `test/src/features/word_quiz/data/local/asset_word_repository_test.dart`
- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Verify: `dart analyze && flutter test`

### Phase 3 — Integrate asset words into quiz notifier
**Goal:** Quiz uses asset words as base pool; server words merge/override by ID. Quiz fully playable offline.

- [x] `lib/src/features/word_quiz/application/word_quiz_notifier.dart:23-42` — in `build()`, load asset words via `assetWordsProvider`, use as base pool; merge server words (server overrides by `id`); fallback to asset-only when server fails
- [x] TDD: `WordQuizNotifier` falls back to asset words when server fetch throws → `test/src/features/word_quiz/application/word_quiz_notifier_test.dart` (extend existing test file)
- [x] TDD: `generateOptions()` returns 4 options when using asset words only (sufficient distractor pool)
- [x] Verify: `dart analyze && flutter test`

### Phase 4 — Nice-to-haves
**Goal:** Add `WordSource` enum and eager preloading for zero-delay quiz start.

- [x] `lib/src/features/word_quiz/domain/word_entry.dart` — add `WordSource` enum (`asset`, `server`), add `@Default(WordSource.asset) WordSource source` field to `WordEntry`
- [x] `lib/src/features/word_quiz/application/word_quiz_notifier.dart` — tag merged words with correct source
- [x] `lib/main.dart` — eagerly read `assetWordsProvider` during app init to preload asset words
- [x] Verify: `dart analyze && flutter test`

## Data layer changes
- `WordEntry.createdAt`: `required DateTime` → `DateTime?` (freezed + json_serializable)
- `WordEntriesTable.createdAt`: `dateTime()()` → `dateTime().nullable()()`
- `AppDatabase.schemaVersion`: 1 → 2; migration drops/recreates `WordEntriesTable` (cache table, safe to drop)
- No Supabase migrations — assets are read-only bundled files

## External integrations
_None._ Asset loading is fully local via `rootBundle`.

## Risks
- Large JSON (~2-4 MB) may cause brief pause on first load; mitigated by `keepAlive` caching and optional eager preload (Phase 4)
- Drift migration drops cached words; acceptable since cache repopulates on next server fetch

## Out of scope
- Data generation pipeline (PDF parsing, Claude API batch)
- Replacing Supabase as word source
- Admin CRUD for asset words
- Offline-first sync for progress
- Splitting assets by difficulty level
- Word deduplication UI
