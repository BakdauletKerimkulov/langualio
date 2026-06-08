# Plan: Full Project Audit — Guidelines, Bugs, Refactoring, Mock Replacement

Source: `ai_specs/007-project-audit-spec.md`
Created: 2026-06-08
Status: draft

## Overview
Bring the codebase into full compliance with `ai_toolkit/` guidelines, fix bugs (stale exceptions, debug toggles), refactor oversized files, and replace all mock/hardcoded data with real Supabase integration. Phase 1 proves the data layer end-to-end for one feature (home), then subsequent phases expand to grammar, profile, UI compliance, and refactoring.

**Spec:** `ai_specs/007-project-audit-spec.md`

## Context
- **Structure:** feature-first — `lib/src/features/{name}/domain|data|application|presentation`
- **State management:** Riverpod codegen (`@riverpod`), AsyncNotifier for async data — `lib/src/features/chat/application/chat_notifier.dart`
- **Reference implementations:** `lib/src/features/chat/data/chat_repository.dart` (repository + keepAlive provider), `lib/src/features/word_quiz/data/remote/word_quiz_remote_repository.dart` (Supabase queries)
- **Testing convention:** test structure mirrors `lib/`, domain + controller tests, mock repos — `ai_toolkit/architecture.md:536-580`
- **Lint + test command:** `flutter analyze && flutter test`
- **Assumptions / Gaps:**
  - Profile feature currently has no `data/` or `application/` layer — both need creation
  - Home and grammar `data/` dirs exist but are empty — repos need creation
  - `daily_goals` table structure not verified in migrations — assumed from spec (title, xp, is_completed, user_id, date)
  - Achievement system is mock and out of scope (N2)
  - `profiles.avatar_url` may be null for most users — UI must handle fallback

## Plan

### Phase 1 — Home feature: mock → Supabase (thin vertical slice)
**Goal:** Prove the repository → AsyncNotifier → AsyncValue.when() pattern end-to-end for home screen.

- [x] TDD: `HomeRepository.fetchUserProgress()` maps Supabase `profiles` + `daily_goals` rows to `UserProgress` model
- [x] `lib/src/features/home/data/home_repository.dart` — create repository with `SupabaseClient` injection, `@Riverpod(keepAlive: true)` provider. Fetch `profiles` for current user + `daily_goals` filtered by user + today's date
- [x] `lib/src/features/home/application/home_provider.dart` — convert `UserProgressNotifier` from sync (returning `UserProgress.mock`) to `AsyncNotifier` fetching from `homeRepositoryProvider`
- [x] `lib/src/features/home/presentation/home_screen.dart` — remove debug `_isEmpty` toggle (R9), use `AsyncValue.when()` for loading/error/data states
- [x] `lib/src/features/home/domain/user_progress.dart` — remove `static const mock` (R16 partial)
- [x] Verify: `flutter analyze && flutter test`

### Phase 2 — Grammar feature: mock → Supabase
**Goal:** Grammar screen loads items + progress from DB.

- [x] TDD: `GrammarRepository.fetchGrammarItems()` maps `grammar_items` + `user_grammar_progress` to `List<GrammarItem>` with correct status (completed/unlocked/locked)
- [x] `lib/src/features/grammar/data/grammar_repository.dart` — create repository fetching from `grammar_items` joined with `user_grammar_progress`
- [x] `lib/src/features/grammar/application/grammar_provider.dart` — convert `GrammarItemsNotifier` to `AsyncNotifier` fetching from `grammarRepositoryProvider`
- [x] `lib/src/features/grammar/presentation/grammar_screen.dart` — use `AsyncValue.when()` for loading/error/data
- [x] `lib/src/features/grammar/domain/grammar_item.dart` — remove `static const mockItems` (R16 partial)
- [x] Verify: `flutter analyze && flutter test`

### Phase 3 — Profile feature: mock → Supabase
**Goal:** Profile screen shows real stats from DB.

- [ ] TDD: `ProfileRepository.fetchUserProfile()` maps `profiles` row to `UserProfile` model
- [ ] `lib/src/features/profile/data/profile_repository.dart` — create repository fetching from `profiles` table (totalXp, streakDays, wordsLearned, accuracy)
- [ ] `lib/src/features/profile/application/profile_provider.dart` — create `AsyncNotifier` reading from `profileRepositoryProvider`
- [ ] `lib/src/features/profile/presentation/profile_screen.dart` — refactor from hardcoded values to `ConsumerWidget` with `AsyncValue.when()` (R15)
- [ ] `lib/src/features/profile/domain/user_profile.dart` — remove `static const mock` (R16 final)
- [ ] Verify: `flutter analyze && flutter test`

### Phase 4 — Bug fixes and stale code cleanup
**Goal:** Remove dead code, fix exceptions, audit routes.

- [ ] `lib/src/core/exceptions/app_exception.dart` — remove e-commerce exceptions: `CartSyncFailedException`, `PaymentFailureEmptyCartException`, `NullProductImageUrlException`, `ParseOrderFailureException`, `ActiveOrdersExistException`, `LocationNotFoundException` (R7)
- [ ] `lib/src/routing/app_router.dart` — verify `/practice` route points to `WordQuizHomeScreen` (already does — R9b). Update `ai_docs/PROJECT.md` route table to reflect `practice → WordQuizHomeScreen` (R9b)
- [ ] `lib/src/features/auth/presentation/login_screen.dart` — replace raw `TextStyle(fontSize: 14)` with theme textStyle (R1)
- [ ] `lib/src/features/auth/presentation/register_screen.dart` — same (R2)
- [ ] `lib/src/features/assessment/presentation/widgets/question_card.dart` — replace hardcoded `TextStyle(fontSize: 16, fontWeight: FontWeight.w700)` with theme (R5)
- [ ] Verify: `flutter analyze && flutter test`

### Phase 5 — Extract private `_buildX` methods to widget classes
**Goal:** Eliminate all `Widget _buildX()` methods per code-style guidelines (R3).

- [ ] `lib/src/features/admin/presentation/admin_word_list_screen.dart` — extract `_buildBody` to separate widget
- [ ] `lib/src/features/admin/presentation/widgets/word_form_fields.dart` — extract `_buildTextField` and `_buildDropdown` to separate widget classes
- [ ] Verify: `grep 'Widget _build' lib/src/` returns zero hits
- [ ] Verify: `flutter analyze && flutter test`

### Phase 6 — File size refactoring
**Goal:** All files in `lib/src/` ≤ 300 lines (R17–R20).

- [ ] `lib/src/features/chat/presentation/chat_screen.dart` (392 lines) — extract message list, input bar, error banner to `widgets/` (R17)
- [ ] `lib/src/features/grammar/presentation/grammar_card.dart` (348 lines) — move `_Header`, `_StatusIcon`, `_ExpandedBody` to `widgets/` (R18)
- [ ] `lib/src/features/admin/presentation/admin_word_form_screen.dart` (338 lines) — extract form sections to `widgets/` (R19)
- [ ] `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` (328 lines) — extract subwidgets to `widgets/` (R20)
- [ ] Verify: no file in `lib/src/` exceeds 300 lines (`find lib/src -name '*.dart' | xargs wc -l | awk '$1 > 300'`)
- [ ] Verify: `flutter analyze && flutter test`

### Phase 7 — `.hardcoded` and `Sizes` compliance + docs
**Goal:** All UI strings use `.hardcoded`, all spacing uses `Sizes` constants (R4, R6, R21).

- [ ] Scan all presentation files — add `.hardcoded` to every bare `Text('...')` literal (R4). Add `import 'string_hardcoded.dart'` where missing
- [ ] Replace hardcoded `EdgeInsets` raw numbers with `Sizes.pX` constants across ~17 files (R6). Keep intentional micro-adjustments (e.g. `EdgeInsets.only(bottom: 2)`) where no matching constant exists
- [ ] `ai_docs/PROJECT.md` — update "Только mock-данные" section to reflect completed mock → real data migration (R21)
- [ ] Verify: `flutter analyze && flutter test`

## Data layer changes
No new migrations needed — all tables (`profiles`, `daily_goals`, `grammar_items`, `user_grammar_progress`) already exist in `001_initial_schema.sql`. RLS policies already configured.

## External integrations
None new — all data comes from existing Supabase tables via the Supabase Flutter SDK.

## Risks
- **`daily_goals` table may have different columns than spec assumes** — verify schema in migration files before implementing Phase 1
- **Existing tests may break** when mock data is removed — run `flutter test` after each phase and fix immediately
- **`.hardcoded` sweep (R4, Phase 7) touches ~24 files** — high risk of merge conflicts if other work is in progress; do this phase last

## Out of scope
- NOT implementing i18n/ARB extraction — `.hardcoded` markers sufficient for now
- NOT adding CI/CD — separate infrastructure spec
- NOT writing comprehensive test suite — only ensure existing tests pass; new test coverage separate effort
- NOT adding push notifications, social auth, or monetization
- NOT touching word_quiz feature — recently refactored, proper data layer exists
- NOT touching assessment feature — already integrated with Supabase
- NOT touching chat feature backend logic (Edge Function) — only refactoring presentation for file size
- NOT creating achievements table/system — deferred (N2)
