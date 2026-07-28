# Spec: Full Project Audit — Guidelines, Bugs, Refactoring, Mock Replacement

Created: 2026-06-08
Status: refined
Refined: 2026-06-08
Source request: `ai_specs/007-find-and-fix-all-in-project.md` — "Проанализируй проект, сначала проверь, соотвествует ли приложение тому, что описано в ai_toolkit папке в корне. Переписать если не так. Затем проверить на баги и пофиксить их."

## Goal

Bring the entire codebase into full compliance with `ai_toolkit/` guidelines, fix all bugs (unsafe unwraps, logic errors), refactor oversized files, and replace all mock/hardcoded data with real Supabase integration — so every feature works end-to-end with the backend.

## Background

**Stack & conventions:**
- Flutter/Dart with Supabase backend (auth, DB, Edge Functions) — `ai_docs/PROJECT.md`
- Feature-first folder structure: `domain/` (pure Dart) → `data/` (repos, Supabase) → `application/` (Riverpod controllers) → `presentation/` (widgets) — `ai_toolkit/architecture.md`
- Riverpod codegen only (`@riverpod`), no legacy providers — `ai_toolkit/riverpod.md`
- GoRouter navigation by name, never `Navigator.push` — `ai_toolkit/gorouter.md`
- Max 300 lines per file, no private `Widget _buildX()` methods — `ai_toolkit/code-style.md`
- All UI strings use `.hardcoded` extension — `ai_toolkit/architecture.md:494-501`
- No `print()`, no `.withOpacity()`, no `.then()`, no `!` without null check — `ai_toolkit/code-style.md`

**Project context:**
- DB schema already has tables for all mock features: `profiles`, `daily_goals`, `grammar_items`, `user_grammar_progress` — `supabase/migrations/001_initial_schema.sql`
- `practice_questions` and `practice_attempts` were dropped in `20260514183825_word_quiz.sql` and replaced by word quiz feature
- Working Supabase repo pattern exists in `lib/src/features/chat/data/chat_repository.dart` — constructor injection, `keepAlive: true` provider
- 4 features use mock data: home (`UserProgress.mock`), grammar (`GrammarItem.mockItems`), profile (hardcoded values in widget), practice (replaced by word_quiz)
- 103 unstaged files on disk — audit targets the current working tree

**Why now:** MVP features are implemented but half the app runs on hardcoded data. The codebase has drifted from toolkit conventions during rapid feature development. This audit ensures code quality before further feature work.

## User Flow

### Happy path

1. Engineer runs `flutter analyze` → zero warnings (after fixes applied)
2. All features (home, grammar, profile) pull real data from Supabase on app start
3. Home screen shows user's actual nickname, level, XP, streak, daily goals from `profiles` + `daily_goals` tables
4. Grammar screen loads items from `grammar_items` table, shows user's progress from `user_grammar_progress`
5. Profile screen shows real stats from `profiles` (totalXp, streakDays, wordsLearned, accuracy) and achievements (initially server-seeded defaults)
6. All screens handle loading and error states via `AsyncValue.when()`

### Error & recovery flows

- If Supabase is unreachable → show error message with retry button (follow `chat_screen.dart` pattern)
- If user is not authenticated → redirect to `/login` (existing guard works)
- If profile data is missing → show empty/default state, not crash

### Edge cases

- Empty state: new user with zero progress → home shows empty view, profile shows defaults
- First-time use: after assessment, home/grammar/profile load from DB (trigger created profile)
- Offline / poor connectivity: show error with retry button on all screens (no local caching for MVP)

## Requirements

### Must Have — Guidelines Compliance

- [ ] R1: Replace raw `TextStyle(fontSize: 14)` with theme textStyle in error display at `lib/src/features/auth/presentation/login_screen.dart:112`. The `state.error!` force-unwrap is guarded by `if (state.error != null)` on line 95 so it's safe, but the TextStyle violates code-style guidelines. Verifiable by: no raw `TextStyle(fontSize:` in auth presentation files.
- [ ] R2: Same as R1 in `lib/src/features/auth/presentation/register_screen.dart:120`. Verifiable by: same.
- [ ] R3: Extract all private `Widget _buildX()` methods in `lib/src/` to separate widget classes. Known violations: `admin_word_list_screen.dart:43` (`_buildBody`), `widgets/word_form_fields.dart:124,134,243` (`_buildTextField`, `_buildDropdown`). Verifiable by: grep for `Widget _build` returns zero hits in `lib/`.
- [ ] R4: All UI-visible strings must use `.hardcoded` extension. Currently 2 of ~24 bare `Text('...')` literals use it. Add `import 'string_hardcoded.dart'` and `.hardcoded` to every `Text('...')` literal in presentation files. Verifiable by: grep `Text\(\s*'[^']*'` in `lib/src/features/` returns zero hits (all should have `.hardcoded`).
- [ ] R5: Replace hardcoded `TextStyle(fontSize: 16, fontWeight: FontWeight.w700)` in `lib/src/features/assessment/presentation/widgets/question_card.dart:195` with `Theme.of(context).textTheme.*`. This is the only known occurrence. Verifiable by: grep `TextStyle(fontSize:` in presentation files returns zero hits.
- [ ] R6: Replace hardcoded `EdgeInsets` raw numbers with `Sizes` constants from `lib/src/core/constants/app_sizes.dart`. There are ~71 instances across 17+ files (heavy in chat_screen, grammar_card, word_quiz, auth screens). **Note:** intentional micro-adjustments (e.g. `EdgeInsets.only(bottom: 2)`) may be kept as-is if no matching `Sizes` constant exists. Verifiable by: grep for `EdgeInsets.*\d+[^p]` shows only `Sizes.pX` usage or justified exceptions.

### Must Have — Bug Fixes

- [ ] R7: `AppException` hierarchy in `lib/src/core/exceptions/app_exception.dart` contains exception classes from a different project (e-commerce template): `CartSyncFailedException` (line 42), `PaymentFailureEmptyCartException` (line 51), `NullProductImageUrlException` (line 60), `ParseOrderFailureException` (line 69), `ActiveOrdersExistException` (line 79), `LocationNotFoundException` (line 88). Remove all and replace with Langualio-specific exceptions if needed. Verifiable by: no shopping-cart, order, or location-related exception classes remain.
- [ ] R8: `handle_new_user()` trigger in `001_initial_schema.sql` uses `name` field and lacks `SET search_path = public` (security issue per `ai_toolkit/firebase.md` → Supabase RPC Security). The fix migration `20260517074956_assessment_fields.sql` already corrects this. Verify the corrected version is what's deployed. Verifiable by: reading current trigger definition.
- [ ] R9: Home screen has debug toggle `bool _isEmpty = false` with `onAvatarTap` switching to empty state (`lib/src/features/home/presentation/home_screen.dart:19,36`). Remove debug toggle. Verifiable by: `_isEmpty` variable no longer exists.
- [ ] R9b: Audit `/practice` route in router config. `ai_docs/PROJECT.md:133` still lists it, but the practice feature was replaced by word_quiz. Remove or redirect the route if it still exists. Verifiable by: no `/practice` route pointing to a deleted screen.

### Must Have — Mock Data Replacement

- [ ] R10: Create `lib/src/features/home/data/home_repository.dart` — fetch user progress from `profiles` + `daily_goals` tables. Follow `chat_repository.dart` pattern (constructor injection, `SupabaseClient`). Field mapping: `UserProgress.nickname` ← `profiles.nickname`, `.avatarUrl` ← `profiles.avatar_url`, `.level` ← `profiles.level`, `.currentXp` ← `profiles.total_xp % targetXp`, `.targetXp` ← computed from level, `.streakDays` ← `profiles.streak_days`. Daily goals: separate query to `daily_goals` filtered by current user + today's date. `completedGoals`/`totalGoals` = count aggregation from results. Verifiable by: file exists, provider returns `UserProgress` from Supabase.
- [ ] R11: Convert `UserProgressNotifier` from sync notifier returning `UserProgress.mock` to `AsyncNotifier` fetching from `homeRepositoryProvider`. Verifiable by: `build()` returns `FutureOr<UserProgress>` loaded from DB.
- [ ] R12: Create `lib/src/features/grammar/data/grammar_repository.dart` — fetch grammar items from `grammar_items` + user progress from `user_grammar_progress`. Verifiable by: file exists, real data loads.
- [ ] R13: Convert `GrammarItemsNotifier` from sync notifier returning `GrammarItem.mockItems` to `AsyncNotifier` fetching from `grammarRepositoryProvider`. Verifiable by: `build()` returns `FutureOr<List<GrammarItem>>` from DB.
- [ ] R14: Create `lib/src/features/profile/data/profile_repository.dart` — fetch user profile + stats from `profiles` table. Verifiable by: file exists.
- [ ] R15: Refactor `ProfileScreen` to be a `ConsumerWidget` reading from a `userProfileProvider` (async) instead of hardcoded values on lines 49–53, 65–96, 109–133. Verifiable by: no hardcoded strings like `'Alex Carter'`, `'3,450'`, `'482'` remain in profile_screen.dart.
- [ ] R16: Remove `static const mock` from `UserProgress` (`lib/src/features/home/domain/user_progress.dart:32-45`) and `UserProfile` (`lib/src/features/profile/domain/user_profile.dart:42-59`). Remove `static const mockItems` from `GrammarItem`. Verifiable by: grep `mock` in domain models returns zero.

### Must Have — File Size Refactoring

- [ ] R17: Refactor `lib/src/features/chat/presentation/chat_screen.dart` (392 lines) — extract message list, input bar, and error banner into `widgets/` subfolder. Target: main file ≤250 lines. Verifiable by: `wc -l` ≤ 300.
- [ ] R18: Refactor `lib/src/features/grammar/presentation/grammar_card.dart` (348 lines) — already has private `_Header`, `_StatusIcon`, `_ExpandedBody` classes, move them to separate files in `widgets/`. Target: main file ≤200 lines. Verifiable by: `wc -l` ≤ 300.
- [ ] R19: Refactor `lib/src/features/admin/presentation/admin_word_form_screen.dart` (338 lines) — extract form sections into `widgets/`. Target: main file ≤250 lines. Verifiable by: `wc -l` ≤ 300.
- [ ] R20: Refactor `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` (328 lines) — extract subwidgets. Target: main file ≤250 lines. Verifiable by: `wc -l` ≤ 300.

### Must Have — Documentation

- [ ] R21: Update `ai_docs/PROJECT.md` "Только mock-данные" section after mock replacement is complete.

### Nice to Have

- [ ] N1: Add `data/` layer to profile feature (currently missing — only domain + presentation).
- [ ] N2: Add achievements system backed by a DB table (currently mock constants). This could be a separate spec.

### Non-functional

- Performance: home/grammar/profile screens must show a loading skeleton within 100ms of navigation, then data within 2s on 3G.
- Accessibility: all interactive elements have min 48x48 tap targets (already enforced by Material 3).
- i18n: all new strings use `.hardcoded` extension (extraction to ARB deferred to separate spec).

## Technical Constraints

**Files to create:**
- `lib/src/features/home/data/home_repository.dart` — fetch `profiles` + `daily_goals` for current user
- `lib/src/features/grammar/data/grammar_repository.dart` — fetch `grammar_items` + `user_grammar_progress`
- `lib/src/features/profile/data/profile_repository.dart` — fetch `profiles` stats for current user
- `lib/src/features/chat/presentation/widgets/chat_input_bar.dart` — extracted from chat_screen
- `lib/src/features/chat/presentation/widgets/chat_message_list.dart` — extracted from chat_screen
- `lib/src/features/grammar/presentation/widgets/grammar_card_header.dart` — extracted from grammar_card
- `lib/src/features/grammar/presentation/widgets/grammar_card_body.dart` — extracted from grammar_card
- Various widget extractions for admin_word_form and word_quiz_home

**Files to modify:**
- `lib/src/features/home/application/home_provider.dart` — AsyncNotifier, remove mock
- `lib/src/features/home/presentation/home_screen.dart` — remove debug `_isEmpty` toggle, use `AsyncValue.when()`
- `lib/src/features/home/presentation/home_active_view.dart` — adapt to async data
- `lib/src/features/grammar/application/grammar_provider.dart` — AsyncNotifier, remove mock
- `lib/src/features/grammar/presentation/grammar_screen.dart` — use `AsyncValue.when()`
- `lib/src/features/profile/presentation/profile_screen.dart` — replace hardcoded data with provider
- `lib/src/features/auth/presentation/login_screen.dart` — fix TextStyle, verify null safety
- `lib/src/features/auth/presentation/register_screen.dart` — same
- `lib/src/features/admin/presentation/admin_word_list_screen.dart` — extract `_buildBody`
- `lib/src/core/exceptions/app_exception.dart` — remove irrelevant exception classes
- `lib/src/features/home/domain/user_progress.dart` — remove `static const mock`
- `lib/src/features/profile/domain/user_profile.dart` — remove `static const mock`
- `lib/src/features/grammar/domain/grammar_item.dart` — remove `static const mockItems`
- ~24 presentation files — add `.hardcoded` to bare UI strings

**Patterns to follow (with citations):**
- Follow `lib/src/features/chat/data/chat_repository.dart` for repository pattern (constructor injection, `SupabaseClient`, `@Riverpod(keepAlive: true)` provider)
- Follow `lib/src/features/chat/application/chat_notifier.dart` for `AsyncNotifier` pattern with `_mounted` check
- Follow `lib/src/features/word_quiz/data/remote/word_quiz_remote_repository.dart` for Supabase query patterns

**Anti-patterns / avoid:**
- Do not add new dependencies — Supabase SDK already covers all DB access needs
- Do not create DTOs for simple tables — domain models with `fromJson` factory are sufficient (project convention per `ai_docs/PROJECT.md`: "domain/ — модели (plain immutable classes, без freezed)")
- Do not duplicate the `handle_new_user` trigger logic — profile is auto-created on signup

**Data layer changes:**
- No new migrations needed — all tables (`profiles`, `daily_goals`, `grammar_items`, `user_grammar_progress`) already exist in `001_initial_schema.sql`
- RLS policies already configured for user-scoped access

**External integrations:** None new — all data comes from existing Supabase tables.

## Edge Cases

See User Flow → Edge cases above. Key additions:

- **User with no daily goals:** home repository returns empty list, UI shows "Нет целей на сегодня" empty state
- **Grammar items not seeded:** grammar screen shows empty state with message, not crash
- **Profile with null avatar_url:** use fallback icon/initials, not broken `NetworkImage`

## Out of Scope

- NOT implementing i18n/ARB extraction — `.hardcoded` markers are sufficient for now, full localization is a separate spec
- NOT adding CI/CD — separate infrastructure spec
- NOT writing comprehensive test suite — only ensure existing tests pass; new test coverage is a separate effort
- NOT adding push notifications, social auth, or monetization
- NOT touching the word_quiz feature — it was recently refactored and has a proper data layer
- NOT touching the assessment feature — it's already integrated with Supabase
- NOT touching the chat feature's backend logic (Edge Function) — only refactoring the presentation layer for file size
- NOT creating an achievements table/system — listed as N2 nice-to-have, deferred

## Validation

**Automated tests:**
- Unit: verify `home_repository.dart` maps Supabase rows to `UserProgress` correctly
- Unit: verify `grammar_repository.dart` maps rows to `GrammarItem` with progress status
- Unit: verify `profile_repository.dart` maps rows to `UserProfile`
- Existing: `flutter test` passes with no regressions

**Manual QA scenarios:**
1. Given a new user after registration + assessment, when navigating to home, then see real nickname/level/XP from DB (not "Alex"), daily goals from `daily_goals` table (or empty state).
2. Given a user with grammar progress, when opening grammar screen, then see items from DB with correct status (completed/unlocked/locked).
3. Given a user with practice history, when opening profile, then see real stats (totalXp, streakDays, wordsLearned, accuracy from `profiles` table).
4. Given no network, when opening home, then see loading spinner → error message with retry button.
5. Given all features loaded, run `flutter analyze` → zero warnings, zero errors.

**Expected behavior under edge conditions:**
- Offline → loading state, then error with retry
- Backend error → error state with message, retry button
- Empty data → appropriate empty state per screen (not crash, not mock data)

## Definition of Done

- [ ] All Must Have requirements (R1–R21) pass automated + manual verification
- [ ] `flutter analyze` returns zero warnings and zero errors
- [ ] `flutter test` passes with no regressions
- [ ] All Manual QA scenarios pass on iOS Simulator
- [ ] No `static const mock` / `mockItems` remain in domain models
- [ ] No files in `lib/src/` exceed 300 lines
- [ ] No private `Widget _buildX()` methods exist in `lib/`
- [ ] No hardcoded UI strings without `.hardcoded` in presentation files
- [ ] `ai_docs/PROJECT.md` updated to reflect mock → real data migration (R21)
- [ ] Spec file linked in the PR description
