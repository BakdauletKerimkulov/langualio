# Commands

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

Workflow commands for feature work. Read all `ai_toolkit/` guideline files (core + the backend in use) before running any of them.

---

## /plan

Read the following files in order:
1. `ai_toolkit/core/` (all guideline files) and `ai_toolkit/backends/{backend}/`
2. All files listed in the "Context → Read:" section of the requirements
3. The requirements file: `ai_specs/{current-feature}/requirements.md`

Generate a detailed implementation plan. Save it to `ai_specs/{current-feature}/plan.md`.

Plan format:

```markdown
# Plan: {Feature Name}

Source: ai_specs/{folder}/requirements.md
Created: {date}

## Overview
One paragraph: what will be built.

## Stages

### Stage 1: {Name}
**Goal:** What this stage achieves
**Files to create/modify:**
- `path/to/file.dart` — what it does
**Steps:**
- [ ] Step 1
- [ ] Step 2
**Verification:** How to confirm this stage works

### Stage 2: {Name}
...

## Data Model Changes
New tables/collections, columns/fields, indexes, access rules, or migrations needed.

## Backend Functions
New or modified server-side functions (RPC, Cloud Functions, Edge Functions).

## Risks & Open Questions
Anything uncertain or needing clarification.
```

Rules:
- 3–7 steps per stage, small enough to review
- Each stage independently verifiable
- Do NOT write code — only the plan
- Respect Out of Scope from requirements

---

## /implement

Read the following files in order:
1. `ai_toolkit/core/` (all guideline files) and `ai_toolkit/backends/{backend}/`
2. All `ai_docs/` files referenced in the plan
3. `ai_specs/{current-feature}/plan.md`

Implement ONLY the stage specified: Stage `$ARGUMENTS`.

Rules:
- Follow code style from `core/code-style.md`
- Follow architecture from `core/architecture.md`
- Follow Riverpod patterns from `core/riverpod.md`
- Follow routing patterns from `core/gorouter.md`
- Follow the backend patterns from `backends/{backend}/`
- Follow test expectations from `core/testing.md`
- Do NOT use deprecated APIs (see `core/flutter.md`)
- Do NOT implement anything from other stages
- Do NOT implement anything marked Out of Scope in requirements
- After implementation, list all files created/modified
- Mark completed steps with `[x]` in plan.md

If a step is ambiguous, state your assumption and proceed.
Do NOT ask questions — implement and note assumptions.

---

## /review

Read `ai_toolkit/` (core + the backend in use).

Review all staged/unstaged changes: `git diff HEAD`

Check for:

1. Code style violations (`core/code-style.md`):
   - Naming conventions
   - File size > 300 lines
   - Private widget methods instead of extracted classes
   - Raw numbers instead of Sizes/gaps
   - `print()` instead of `debugPrint`/AppLogger
   - Missing `const` constructors

2. Architecture violations (`core/architecture.md`):
   - Backend SDK imports in `domain/` layer
   - Business logic in `presentation/` layer
   - Repository returning `Map`/raw rows instead of domain model
   - `Navigator.push` instead of GoRouter

3. Riverpod violations (`core/riverpod.md`):
   - `ref.watch` inside async methods
   - Missing `mounted` check after `await` in auto-dispose controllers
   - Provider created for ephemeral/UI-only state
   - Legacy `StateProvider`/`StateNotifierProvider`

4. Backend violations (`backends/{backend}/`):
   - Missing mandatory id/created/updated fields
   - Client-side timestamps instead of server timestamps/defaults
   - Read-modify-write without a transaction / conditional write
   - Missing idempotency strategy
   - Client writing server-authoritative fields
   - Missing or too-permissive access rules; privileged functions callable by anonymous users
   - Server function missing auth/validation/error-handling steps
   - Secrets or magic values inline instead of top-level constants
   - Swallowed exceptions, missing logging context

5. Flutter violations (`core/flutter.md`):
   - Deprecated APIs (`withOpacity`, old TextTheme names, etc.)
   - `Platform.isIOS` without `kIsWeb` check

6. Test gaps (`core/testing.md`):
   - New domain/business logic without tests
   - Bugfix without a regression test

If violations found: list each with file path and line, suggest fix, do NOT commit.
If clean: report "No violations found. Ready to commit."

---

## /commit

Review staged and unstaged changes: `git status --short`, `git diff HEAD`

1. Run the `/review` checklist mentally. If red flags found — report them and DO NOT commit.

2. If clean, stage all changes: `git add -A`

3. Write commit message in Conventional Commits format: `type(scope): description`
   - Types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`
   - Scope: feature name (auth, orders, profile, etc.)
   - Description: imperative, lowercase, no period

   Examples:
   - `feat(orders): add order creation via server function`
   - `fix(checkout): prevent double-charge on concurrent submits`
   - `refactor(auth): extract onboarding state machine to separate file`
   - `docs(ai_docs): add data model documentation`

4. Commit: `git commit -m "type(scope): description"`

5. If `$ARGUMENTS` provided, use as context for the commit message.

---

## Documentation Sync (part of every task's Definition of Done)

Stale docs are worse than no docs — an agent reading them acts on a false picture. A task that changes any of the following is not complete until the matching doc is updated in the same change:

| Change | Update |
|---|---|
| Table/collection, field, access rule, RPC | `ai_docs/PROJECT.md` data model section |
| Server function added/changed (contract, limits, response shape) | `ai_docs/PROJECT.md` backend functions section |
| Route added/changed | `ai_docs/PROJECT.md` routing section |
| New convention or hard-won lesson | The relevant `ai_toolkit/` file |

`/review` includes a check: does the diff touch the data model, server functions or routes while `ai_docs/` is untouched? If yes — flag it.
