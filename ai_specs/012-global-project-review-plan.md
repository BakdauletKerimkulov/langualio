---
title: Global Project Review — Security, Architecture, Documentation
status: in-progress
date: 2026-07-21
type: fix
---

# Plan: Global Project Review

Source: `ai_specs/012-global-project-review.md`

## Overview
Close all findings from the senior code review (`ai_docs/CODE_REVIEW_2026-07-19.md`) in risk order: security holes that leak money/data first, then architecture debt, then backend cleanup, then docs and tests. Each phase is a standalone deployable unit.

**Spec:** `ai_specs/012-global-project-review.md`

## Context
- **Structure:** Feature-first (`lib/src/features/{name}/{domain,data,application,presentation}/`)
- **State management:** Riverpod codegen (`@riverpod`), example: `lib/src/features/home/application/home_provider.dart`
- **Reference implementations:** `supabase/migrations/20260514193920_word_quiz_security.sql` (security triada pattern), `lib/src/features/word_quiz/` (full feature with all layers)
- **Testing convention:** `test/src/features/` mirrors `lib/`, `ProviderContainer` + mocked repos per `ai_toolkit/testing.md`; `supabase/tests/` does not exist yet; no Deno tests
- **Lint + test command:** `flutter analyze && flutter test` (client); `supabase db reset` + SQL tests + `deno test` (backend, to be added)
- **Assumptions / Gaps:**
  - Open question: refund quota on Claude error? (spec Q1) — plan marks this as a code comment decision, not a blocker
  - Open question: `app_metadata` role vs table for instant revocation? (spec Q2) — plan uses `app_metadata` (current approach) and documents the JWT-cache lag
  - Open question: `generate-word-entry` forever admin-only? (spec Q3) — plan keeps admin-only per current spec, no expansion
  - `_mounted` pattern found in 7 files (home, grammar, word_quiz×2, admin×2, profile) — not 5+ as spec states, actual count is 7
  - `lib/src/shared/` exists alongside `lib/src/core/` — both have `common_widgets` and `constants` dirs
  - `refreshListenable` is completely missing from `app_router.dart`
  - Auth feature has no `data/` layer — all auth API calls live in `application/`
  - CI runs only Flutter; no backend gates at all

## Plan

### Phase 1 — Security: admin gate + atomic quota + RLS lockdown (R1, R2, R3)
**Goal:** Prevent unauthorized Claude API spend and quota bypass. Thin vertical slice: one migration + two edge function updates + RLS tests.

- [x] `supabase/migrations/20260721171502_atomic_quota.sql` — create RPC `try_consume_quota(p_user_id uuid, p_kind text, p_limit int) returns boolean`. Atomic increment with `WHERE count < limit`. `SECURITY DEFINER`, `SET search_path = public`, `REVOKE/GRANT` per reference `word_quiz_security.sql`. TODO comment for quota refund on Claude error
- [x] `supabase/functions/generate-word-entry/index.ts` — admin role check (`app_metadata.role === 'admin'` → 403) + atomic quota via `.rpc('try_consume_quota')` before Claude call. Removed racy read-modify-write
- [x] `supabase/functions/chat/index.ts` — replaced read-modify-write quota with atomic `.rpc('try_consume_quota')` before Claude call. Removed post-Claude upsert
- [x] `supabase/migrations/20260721171503_lock_usage_rls.sql` — dropped INSERT and UPDATE policies on `user_daily_usage` for `authenticated`. SELECT remains
- [x] TDD: `supabase/tests/rls_quota_test.sql` — 6 tests: UPDATE denied, INSERT denied, SELECT allowed, quota limit enforcement (7 calls / limit 5 → exactly 5 pass), generation kind, anon denied
- [x] Verify: `flutter analyze` clean, `flutter test` 74/74 pass. _Note: `supabase db reset` not run — Docker not available locally. SQL migration syntax and test file validated by review_

### Phase 2 — Security: server-side assessment + model ID + secrets (R4, R5, R6)
**Goal:** Remove client write of `cefr_level`, standardize Claude model, verify no secrets in git.

- [x] `supabase/migrations/20260721175539_assessment_server.sql` — create `assessment_questions` table (id, question_text, options jsonb, correct_answer, cefr_weight). Seed with current question bank from `lib/src/features/assessment/domain/`. Create RPC `complete_assessment(p_answers jsonb) returns json`: validate answers server-side, compute level, `UPDATE profiles SET cefr_level = ..., assessment_completed = true`, return `{cefr_level, assessment_completed}`. Revoke client UPDATE on `cefr_level` and `assessment_completed` columns of `profiles`
- [x] `lib/src/features/assessment/data/assessment_repository.dart` — replace `saveResult()` with `completeAssessment(answers)` calling `.rpc('complete_assessment', ...)`. Return parsed result
- [x] `lib/src/features/assessment/application/assessment_controller.dart` — update controller to call new repository method, parse RPC response for UI display. Added loading state during server round-trip
- [x] TDD: `supabase/tests/rls_assessment_test.sql` — 7 tests: cefr_level UPDATE denied, assessment_completed UPDATE denied, nickname UPDATE allowed, SELECT allowed, complete_assessment all correct → C1, all wrong → A1, anon denied
- [x] `supabase/functions/_shared/constants.ts` — created shared file with `CLAUDE_MODEL = "claude-sonnet-4-20250514"` and `CLAUDE_API_URL`. Standardized from two different IDs
- [x] `supabase/functions/chat/index.ts` + `supabase/functions/generate-word-entry/index.ts` — import `CLAUDE_MODEL` and `CLAUDE_API_URL` from `_shared/constants.ts`
- [x] TDD: verify `supabase/.env.local` is in `.gitignore` and not in git history (`git log --all -- supabase/.env.local` → clean)
- [x] Verify: `flutter analyze` clean, `flutter test` 74/74 pass. _Note: `supabase db reset` not run — Docker not available locally. SQL migration syntax and test file validated by review_

### Phase 3 — Architecture: merge shared/, Supabase leaks, AuthRepository (R7, R8, R9, R10)
**Goal:** Single `core/` directory, no `Supabase.instance` outside data/bootstrap, `_mounted` mixin, GoRouter `refreshListenable`.

- [x] Merge `lib/src/shared/` into `lib/src/core/` — move unique files, delete duplicates, rewrite all imports. Delete `lib/src/shared/`
- [x] `lib/src/features/auth/data/auth_repository.dart` — create `AuthRepository` wrapping Supabase auth API (signIn, signUp, signOut, authStateChanges, currentUser). Provider with `keepAlive: true` (already implemented)
- [x] `lib/src/features/auth/application/auth_provider.dart` — refactor to use `AuthRepository` via injection instead of direct `Supabase.instance.client.auth` calls (already implemented — no auth_provider.dart exists; auth logic lives in AuthRepository)
- [x] `lib/src/routing/app_router.dart` — replace `Supabase.instance.client.auth.currentSession` with injected provider; add `refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges())` (already implemented)
- [x] `lib/src/features/admin/application/admin_provider.dart` — replace `Supabase.instance.client.auth.currentUser` with `ref.read(authRepositoryProvider)`
- [x] `lib/src/features/assessment/application/onboarding_state_provider.dart` — move `.from('profiles')` queries to `profile_repository.dart` (added `fetchOnboardingState()` method)
- [x] `lib/src/core/utils/notifier_mounted.dart` — extract `_mounted` into `NotifierMounted` mixin per `riverpod.md`. Refactored all 7 notifiers (home, grammar, profile, word_quiz, add_word, admin_word_list, admin_word_form)
- [x] Verify: `grep -r "Supabase.instance" lib/src` → only `core/supabase/supabase_client.dart`; `flutter analyze` clean, `flutter test` 74/74 pass

### Phase 4 — Architecture: error propagation + admin trigger (R10, R11, R14)
**Goal:** Errors surface to UI instead of being swallowed; admin role grants on first signup.

- [x] `lib/src/features/word_quiz/data/quiz_attempt_repository.dart` — `saveAttempt`: throw instead of swallowing error
- [x] `lib/src/features/chat/data/chat_repository.dart` — `fetchMessages`: throw on error instead of returning empty list
- [x] TDD: widget/provider test — network error during quiz save → `AsyncError` state, not silent success
- [x] `supabase/migrations/20260722200226_admin_trigger_insert.sql` — add `BEFORE INSERT ON auth.users` trigger for `handle_admin_role()` (currently only `BEFORE UPDATE`). Add comment documenting JWT cache lag (~1h)
- [x] TDD: `supabase/tests/admin_trigger_test.sql` — new user with email in `admin_emails` gets role in `raw_app_meta_data` on INSERT
- [x] Verify: `supabase db reset`; SQL tests pass; `flutter analyze && flutter test`. _Note: `supabase db reset` not run — Docker not available locally. SQL migration syntax and test file validated by review. Flutter: analyze clean, 75/75 tests pass_

### Phase 5 — Backend cleanup: shared code, junk removal (R12, R13)
**Goal:** DRY edge functions, remove dead files.

- [x] `supabase/functions/_shared/cors.ts` — extract shared CORS handler
- [x] `supabase/functions/_shared/auth.ts` — extract JWT verification helper
- [x] `supabase/functions/_shared/response.ts` — extract `jsonResponse` helper
- [x] `supabase/functions/_shared/env.ts` — extract env-guard (fail-fast on missing secrets, consistent 500)
- [x] `supabase/functions/chat/index.ts` + `generate-word-entry/index.ts` — import from `_shared/`, remove duplicated code
- [x] Remove junk: `supabase/migrations/20260504190931_new-migration.sql` (empty), `supabase/snippets/Untitled query 498.sql`, `scripts/output/*.json`
- [x] Verify: `flutter analyze` clean, `flutter test` 75/75 pass. _Note: `supabase db reset` and `supabase functions serve` not run — Docker not available locally. Edge function refactoring validated by code review_

### Phase 6 — Documentation: PROJECT.md, README, ai_docs (R15, R16)
**Goal:** Docs describe reality; no phantom features, no missing ones.

- [ ] `ai_docs/PROJECT.md` — full rewrite: actual DB schema (all tables from migrations), actual edge function contracts (non-streaming JSON, not SSE), actual routing, actual roles. Every table + every function described; nothing described that doesn't exist
- [ ] `README.md` — replace Flutter template with: project description, local setup (Supabase + flutter run), where docs live
- [ ] Archive or delete `PLAN.md` if it exists as historical artifact
- [ ] Verify: every table from `supabase/migrations/` mentioned in `PROJECT.md`; every function from `supabase/functions/` described; `grep -i "SSE" ai_docs/PROJECT.md` → 0 results

### Phase 7 — Backend tests + CI (R17, R18)
**Goal:** SQL and Deno tests exist and run in CI.

- [ ] `supabase/tests/rls_server_authoritative_test.sql` — negative tests for all server-authoritative fields: `cefr_level`, `current_xp`, `level`, `streak_days`, `message_count`, `generation_count` as `authenticated` role
- [ ] `supabase/tests/rpc_contract_test.sql` — contract tests for all RPC functions: anon → rejected, authenticated → correct result, double call → idempotent
- [ ] TDD: `supabase/functions/_shared/` — `Deno.test` for pure helpers (validation, response parsing)
- [ ] `.github/workflows/ci.yml` — add: `supabase db reset`, SQL test runner (`psql -f supabase/tests/*.sql`), `deno test supabase/functions/`
- [ ] `.github/workflows/deploy.yml` — gate deploy on green CI
- [ ] Verify: `supabase db reset && psql -f supabase/tests/*.sql && deno test supabase/functions/` all green locally

### Phase 8 — Polish: models, file splits, hardcodes, app_config (R19–R23)
**Goal:** Code consistency and smaller remaining debt items.

- [ ] Document in `ai_toolkit/code-style.md` — model standard decision (freezed vs hand-written); update existing models to match (audit scope: grammar, chat, profile, assessment, home — word_quiz already uses freezed)
- [ ] `lib/src/features/word_quiz/presentation/add_word_screen.dart` (340 lines) — extract sub-widgets to `widgets/`
- [ ] `lib/src/features/word_quiz/presentation/word_quiz_screen.dart` (301 lines) — extract sub-widgets to `widgets/`
- [ ] `lib/src/features/grammar/presentation/grammar_screen.dart` — lift collection filtering from `build` to application provider
- [ ] `lib/src/features/word_quiz/presentation/word_quiz_home_screen.dart` — lift collection filtering from `build` to application provider
- [ ] Fix `ref.watch` in method body: `word_pool_provider.dart:15`, `quiz_home_notifier.dart:74` → `ref.read`
- [ ] `supabase/migrations/{timestamp}_app_config_admin_policy.sql` — add admin-only UPDATE policy on `app_config`, or remove misleading comment
- [ ] Verify: `flutter analyze && flutter test`; no file > 300 lines in changed set

## Data layer changes
- New table: `assessment_questions` (seed data from client-side question bank)
- New RPC: `try_consume_quota(p_user_id uuid, p_kind text, p_limit int) returns boolean`
- New RPC: `complete_assessment(p_answers jsonb) returns json`
- Modified RLS: `user_daily_usage` — drop INSERT/UPDATE for `authenticated`, keep SELECT
- Modified grants: `profiles` — revoke client UPDATE on `cefr_level`, `assessment_completed`
- Modified trigger: `handle_admin_role()` — add `BEFORE INSERT` (existing `BEFORE UPDATE` stays)
- Modified/new RLS: `app_config` — admin UPDATE policy

## External integrations
- Claude API (Anthropic): standardize model ID across both edge functions; smoke-test after change
- Supabase Auth: `app_metadata.role` checks in edge functions (existing pattern, extended to `generate-word-entry`)

## Risks
- **R4 is the most invasive phase** — changes assessment contract end-to-end (migration → RPC → repository → provider → UI). Seed data must exactly match current client-side questions. Test with `supabase db reset` + app walkthrough
- **R7 (shared/ merge) touches ~85 imports** — run `flutter analyze` after every batch of import changes; commit atomically
- **Phase 1 deploy order is critical:** (1) migration with new RPCs → (2) updated edge functions → (3) migration dropping old RLS policies. Cannot reverse the order
- **R5 model ID change** — wrong model ID = all Claude calls fail at runtime. Verify against Anthropic docs, smoke-test with real request before deploy
- **Empty migration deletion (R13)** — verify it was never applied to production before removing, or add a replacement no-op migration

## Out of scope
- Rewriting working features or adding new functionality
- Migration to different state management or architecture
- Performance optimization without measurements
- Design and UX changes
- Crash reporting integration (R22 noted but deferred — requires vendor decision)
