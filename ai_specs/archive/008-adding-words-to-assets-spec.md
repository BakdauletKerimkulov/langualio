# Spec: Bundle B1 Vocabulary as Local Asset

Created: 2026-06-14
Status: refined
Refined: 2026-06-14
Source request: ai_specs/008-adding-words-to-assets.md

## Goal

Bundle the full Cambridge B1 vocabulary (~2000 words) as a JSON asset file so users can take quizzes immediately after install — no network required, no server dependency for the initial word pool. Admin-created words from Supabase supplement the asset pool at runtime.

## Background

**Stack & conventions:** Flutter + Riverpod (codegen), freezed models, feature-first architecture (`domain/data/application/presentation`). Domain models are pure Dart — no Firebase/Supabase imports. Repositories live in `data/` and return domain models. JSON serialization via `json_serializable` + freezed. See `ai_toolkit/architecture.md`, `ai_toolkit/riverpod.md`, `ai_toolkit/code-style.md`.

**Project context:** The `WordEntry` model (`lib/src/features/word_quiz/domain/word_entry.dart:10-25`) currently requires `createdAt` as non-nullable. The quiz notifier (`lib/src/features/word_quiz/application/word_quiz_notifier.dart:33-42`) fetches words from Supabase via `fetchTodaysWords()`, falling back to SharedPreferences cache. There is no asset-loading path. The `WordMeaning` model (`lib/src/features/word_quiz/domain/word_meaning.dart:9-18`) supports rich data: part of speech, translation, definitions, examples. The Drift table (`lib/src/features/word_quiz/data/local/word_entries_table.dart:17`) also has `createdAt` as non-nullable. The `pubspec.yaml` (line 40-41) has no `assets:` section.

**Why now:** Users currently see an empty quiz if the server is unreachable or no words are published. Bundling B1 words provides immediate value on first launch and full offline quiz capability.

## User Flow

### Happy path

1. User installs app and opens the quiz feature.
2. System loads ~2000 B1 words from `assets/data/b1_words.json` on first access.
3. Quiz selects today's words from the asset pool (using existing quiz-day logic).
4. User takes quiz — experience is identical to server-sourced words.
5. If server words are also available, they are merged into the pool (server words override asset words with the same `id`).

### Alternative flows

- If the user has network: server words load normally and merge with asset words. Server words with matching IDs take precedence (fresher data).
- If admin publishes a new word not in assets: it appears alongside asset words seamlessly.

### Error & recovery flows

- If asset JSON is malformed or fails to parse: log error, fall back to server-only flow. Quiz still works if network is available.
- If both asset loading and server fetch fail: quiz shows empty state (existing behavior, no regression).

### Edge cases

- Empty state: impossible with bundled assets — always at least ~2000 words available.
- First-time use: asset words are available immediately, no onboarding delay.
- Very large dataset: ~2000 words as JSON ≈ 2-4 MB. Loaded once, cached in memory. Acceptable for mobile.
- App update with new assets: new asset file replaces old one. No migration needed — assets are read-only.

## Requirements

### Must Have

- [ ] R1: Make `createdAt` nullable on `WordEntry` (currently `required DateTime createdAt`). Asset words will have `null` for this field. Verifiable by: `build_runner build` succeeds, `WordEntry.fromJson({'id': 'x', 'word': 'x', 'level': 'b1', 'meanings': [...], 'created_at': null})` returns model with `createdAt == null`, existing tests still pass.
- [ ] R2: Make `createdAt` nullable on `WordEntriesTable` Drift schema (`dateTime().nullable()()`). Run Drift codegen. Verifiable by: Drift-generated code compiles without errors.
- [ ] R2.5: Bump `AppDatabase.schemaVersion` from 1 to 2 in `lib/src/core/local_storage/drift.dart` and add a migration strategy. Since `WordEntriesTable` is a cache (not user data), the simplest approach is to drop and re-create the table on upgrade: `onUpgrade: (m, from, to) async { if (from < 2) { await m.deleteTable('word_entries_table'); await m.createAll(); } }`. Verifiable by: app with existing cached words upgrades without crash; fresh install works normally.
- [ ] R3: Register `assets/data/` in `pubspec.yaml` under `flutter.assets`. Verifiable by: `flutter pub get` succeeds, asset is accessible at runtime.
- [ ] R4: Create `AssetWordRepository` in `lib/src/features/word_quiz/data/local/asset_word_repository.dart` that loads and deserializes `assets/data/b1_words.json` into `List<WordEntry>`. Verifiable by: unit test loads the JSON and returns correctly typed list.
- [ ] R5: Create a Riverpod functional provider (`assetWordsProvider`, `@Riverpod(keepAlive: true)`) in `asset_word_repository.dart` that calls `AssetWordRepository.loadWords()` and caches the result. Separate from the repository provider itself. Verifiable by: provider returns non-empty list after first read.
- [ ] R6: Integrate asset words into `WordQuizNotifier.build()` as the base word pool. When server words are unavailable, use asset words. When server words are available, merge (server overrides by `id`). Verifiable by: quiz shows words even when offline/server unreachable.
- [ ] R7: When asset words are merged into the base pool, `generateOptions()` draws distractors from `session.todayWords` (which now includes asset words), ensuring a sufficient distractor pool even offline. No change to `fetchAllWords()` is needed — it is not used by `generateOptions()`. Verifiable by: `generateOptions()` returns 4 options even when fully offline.
- [ ] R8: Create a placeholder `assets/data/b1_words.json` with the correct schema (at least 5 sample words) so the app compiles and the loading path is testable. The full ~2000 words will be generated separately via AI batch script. Verifiable by: app runs, quiz loads sample words from asset.

### Nice to Have

- [ ] N1: Add a `source` field to `WordEntry` (`enum WordSource { asset, server }`) to distinguish origin at runtime. Useful for analytics and debugging.
- [ ] N2: Preload asset words during app startup (e.g., eagerly read `assetWordsProvider` in `main()` or a startup provider) to avoid any delay when user first opens quiz. Note: no `AppStartupWidget` exists in this project — startup logic is in `main.dart`.

### Non-functional

- Performance: asset JSON should parse in <500ms on mid-range device. ~2000 entries with nested meanings.
- App size: JSON asset ≈ 2-4 MB. Acceptable; no compression needed.
- i18n: not applicable — word content is bilingual by nature (English words, Russian translations).

## Technical Constraints

**Files to create:**

- `assets/data/b1_words.json` — bundled B1 vocabulary in `List<WordEntry>` JSON format (placeholder with ~5 sample words initially)
- `lib/src/features/word_quiz/data/local/asset_word_repository.dart` — loads and parses asset JSON, exposes Riverpod provider

**Files to modify:**

- `lib/src/features/word_quiz/domain/word_entry.dart` (line 22) — change `required DateTime createdAt` → `DateTime? createdAt`
- `lib/src/features/word_quiz/data/local/word_entries_table.dart` (line 17) — change `dateTime()()` → `dateTime().nullable()()` for `createdAt`; update `toModel()` and `toCompanion()` extensions accordingly
- `lib/src/core/local_storage/drift.dart` (line 24) — bump `schemaVersion` from 1 to 2; add migration to drop/recreate `WordEntriesTable`
- `lib/src/features/word_quiz/data/remote/word_quiz_repository.dart` — no changes needed (server words still have `createdAt` from DB)
- `lib/src/features/word_quiz/application/word_quiz_notifier.dart` (lines 23-42) — integrate asset words as fallback/base pool in `build()` method
- `lib/src/features/admin/data/admin_repository.dart` — no changes needed. `_convertFlatToWordEntry` passes `DateTime.now()` (valid for nullable field). `createWord` omits `created_at` from insert row (server default handles it)
- `pubspec.yaml` (line 41) — add `assets:` section with `- assets/data/`
- Run `build_runner` to regenerate `.freezed.dart` and `.g.dart` files

**Patterns to follow (with citations):**

- Follow the JSON deserialization pattern from `word_entries_table.dart:26-45` (`jsonDecode` → `WordEntry.fromJson` mapping).
- Follow the repository + Riverpod provider pattern from `word_quiz_repository.dart:183-189` for the new `AssetWordRepository`.
- Follow the `keepAlive: true` functional provider pattern from `ai_toolkit/riverpod.md` for the asset words provider.

**Anti-patterns / avoid:**

- Do not load asset JSON on every quiz session — load once, cache in provider memory.
- Do not add a new dependency for asset loading — `rootBundle` from `flutter/services.dart` is built-in.
- Do not parse the PDF at runtime — the JSON asset is pre-generated offline.
- Do not modify `WordMeaning` — it is already fully compatible (all fields match the expected asset schema).

**Data layer changes:**

- Assets are read-only files bundled with the app — no Supabase migrations needed.
- Drift table schema change (`createdAt` nullable) requires: (1) Drift codegen re-run, (2) `AppDatabase.schemaVersion` bump from 1 → 2, (3) migration handler to drop/recreate `WordEntriesTable` (it's a cache, not user data — safe to drop on upgrade).

**External integrations:** None. Asset loading is fully local.

## Asset JSON Schema

Each entry in `b1_words.json` follows the `WordEntry.toJson()` format. **Important:** `build.yaml` configures `field_rename: snake`, so all JSON keys must be snake_case (not camelCase). DateTime fields must be ISO8601 strings or `null`.

```json
[
  {
    "id": "b1_ability",
    "word": "ability",
    "ipa": "/əˈbɪl.ə.ti/",
    "level": "b1",
    "meanings": [
      {
        "part_of_speech": "noun",
        "translation": "способность",
        "alternative_translations": ["умение", "навык"],
        "definition_en": "the physical or mental power or skill needed to do something",
        "definition_ru": "физическая или умственная сила или навык, необходимый для выполнения чего-либо",
        "example_en": "She has the ability to learn languages quickly.",
        "example_ru": "Она обладает способностью быстро учить языки."
      }
    ],
    "topic": null,
    "tags": [],
    "created_at": null,
    "updated_at": null,
    "status": null,
    "created_by": null
  }
]
```

**ID convention:** `b1_{word}` (lowercase, underscores for spaces/hyphens). Deterministic — avoids duplicates and enables server override by matching ID.

## Out of Scope

- **NOT** building the data generation pipeline (PDF parsing, Claude API batch calls) — this is a separate offline script, not part of the app. The spec assumes a pre-generated `b1_words.json` file will be placed in `assets/data/`.
- **NOT** replacing Supabase as the word source — asset words are the base pool; server words extend and override.
- **NOT** adding admin CRUD for asset words — admin manages server-side words only. Assets are read-only and updated via app releases.
- **NOT** implementing offline-first sync (writing progress back when offline) — existing pending-attempts queue handles this already.
- **NOT** splitting asset by difficulty level (separate A1/A2/B1 files) — single file is sufficient for ~2000 words.
- **NOT** adding word deduplication UI — server override by ID is implicit and automatic.

## Validation

**Automated tests:**

- Unit: `AssetWordRepository` loads sample JSON, returns `List<WordEntry>` with correct field mapping. File: `test/src/features/word_quiz/data/local/asset_word_repository_test.dart`.
- Unit: `WordEntry` with `createdAt: null` serializes/deserializes correctly (round-trip JSON test).
- Unit: `WordQuizNotifier` falls back to asset words when server fetch fails (mock `WordQuizRepository` to throw, verify asset words are used).

**Manual QA scenarios:**

1. Given airplane mode ON, when user opens quiz, then quiz loads with asset words and is fully playable.
2. Given server has published words, when user opens quiz, then server words appear alongside/override matching asset words.
3. Given fresh install with no cache, when user opens quiz, then words appear immediately (no loading spinner beyond initial parse).
4. Given admin creates a word with same ID as an asset word (`b1_ability`), when quiz loads, then server version is used (overrides asset).

**Expected behavior under edge conditions:**

- Offline → quiz works fully with asset words; attempts queued locally.
- Backend error → asset words used as fallback; no user-facing error for word loading.
- Empty data → impossible with bundled assets (always ≥5 words in placeholder, ≥2000 in production).

## Definition of Done

- [ ] All Must Have requirements pass automated tests
- [ ] All Manual QA scenarios pass on iOS simulator and Android emulator
- [ ] No new lint warnings; `dart analyze` clean
- [ ] `build_runner build` succeeds without errors
- [ ] Matches `ai_toolkit/` style guide (file size ≤300 lines, no raw numbers, no `print()`)
- [ ] Spec file linked in the PR description
