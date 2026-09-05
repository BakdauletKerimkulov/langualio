# Spec-Driven Development Rules (`ai_toolkit/`, `ai_docs/`, `ai_specs/`)

> **This file is the source of truth** for folder structure, file naming, metadata format, and statuses. Slash commands (`/spec`, `/refine`, `/plan`, `/work`, `/bootstrap`) implement the workflow but MUST conform to this file — they reference it instead of duplicating its rules. On conflict, this file wins.
>
> Canonical copy lives in `agentic-coding-toolkit/rules/`. Each project gets a copy in its root (via `/bootstrap`), referenced from `CLAUDE.md` / `AGENTS.md`. Any AI agent working on the project MUST read this file, then the relevant files in `ai_toolkit/` and `ai_docs/`, before planning, editing, or creating anything.

---

## 1. Three folders, three purposes

| Folder | Contains | Changes | Portable to other projects |
|---|---|---|---|
| `ai_toolkit/` | Universal engineering rules (Flutter, Riverpod, Firebase, GoRouter, code style) | Rarely — only when the stack or best practices change | Yes — copy as-is |
| `ai_docs/` | Project-specific knowledge: what THIS app is, its schema, its decisions, lessons learned while working | Grows continuously as the project evolves | No |
| `ai_specs/` | Feature ledgers, specs, and implementation plans | Created per feature, archived when done | No |

Decision rule for any new piece of knowledge:

1. True for ANY Flutter project? → `ai_toolkit/`
2. True for this project and stays true after the current feature ships? → `ai_docs/`
3. Describes a single change? → `ai_specs/`

---

## 2. `ai_toolkit/` — universal foundation (rarely changes)

Flat folder. One file per technology:

```
ai_toolkit/
  RULES.md           # binding rule index — read in full, every command, every time
  RULES-backend.md   # the same for the project's backend
  architecture.md    # feature-first structure, layers, repository/DTO rules
  code-style.md      # naming, formatting, lint, localization, responsive
  flutter.md         # framework versions, deprecated APIs
  riverpod.md        # provider patterns, codegen, ephemeral vs app state
  gorouter.md        # navigation patterns
  testing.md         # test pyramid, robots, backend tests, CI gates
  docs-sync.md       # what must be documented in the same change
  firebase.md / supabase.md (+ edge-functions.md)   # the backend in use
```

`RULES.md` is a **digest**: it states every binding rule in one line with a pointer to the file that explains it. Commands read the digest always, and the full file for the area they touch. When you change a rule in a source file, update its line in `RULES.md` in the same commit — `sync-toolkit.sh --check` flags drift.

Rules:

- Nothing project-specific: no route lists, no collection names, no model fields. Each file states this explicitly and points to `ai_docs/` for project details.
- **Dependency direction is one-way.** `ai_docs/` and `ai_specs/` may reference specific `ai_toolkit/` files; `ai_toolkit/` may only reference the `ai_docs/` folder generically ("project-specific details → `ai_docs/`") — never a specific filename. Hard references would break the moment the toolkit is copied to another project. References between files inside `ai_toolkit/` are fine.
- Updated only when the stack changes (new Flutter/Riverpod major version, new package adopted) — never as part of feature work.
- Reused across projects: treat it as a portable asset, keep it generic.

---

## 3. `ai_docs/` — project knowledge (grows over time)

Flat root + one `solutions/` subfolder for accumulated lessons:

```
ai_docs/
  GLOSSARY.md             # canonical domain vocabulary: one term = one word, in code and in UI
  PROJECT.md              # what the app does, stack, feature modules, roles, key domain models
  DATA_MODEL.md           # collections/tables, document/row shapes, field types, access-rule summary
  BACKEND_FUNCTIONS.md    # server functions list, triggers, secrets, idempotency notes
  EXTERNAL_SERVICES.md    # non-obvious service choices (maps, payments) with "AI warning" notes
  TESTING.md              # what must be tested, mocking approach, commands
  solutions/              # one subfolder per category below
```

Root filenames may be adapted to the backend (`FIRESTORE_SCHEMA.md`, `CLOUD_FUNCTIONS.md` for Firebase; `SCHEMA.md`, `EDGE_FUNCTIONS.md` for Supabase) as long as `PROJECT.md` names them. `ai_toolkit/` must never hard-reference any of these filenames — see the dependency rule in § 2.

Two kinds of content:

- **Fundamentals** (root files) — written once at project setup, edited when architecture/schema/services change. Updated **in the same PR** as the code change that invalidates them.
- **Accumulated knowledge** (`solutions/`) — added after work is done (the "compound" step): every root-caused bug, hard-won CI fix, or planning lesson becomes a short file so it is never re-discovered.

### `GLOSSARY.md` — vocabulary is part of the design

Naming drift is the cheapest defect to prevent and the most expensive to unwind: when the spec says «заказ», the model is `Offer`, and the UI says «объявление», every later agent picks whichever word its context happened to contain, and the divergence ends up in the schema.

```markdown
## Terminology

**Order** (`Order`, UI: «заказ») — a reservation of a specific item by a specific buyer. Created at checkout, never before.
NOT: «объявление» (that is an `Item`), NOT «bid».

**Item** (`Item`, UI: «объявление») — what a seller publishes. Exists without any order.
```

Rules:

- One entry = one concept: the canonical English identifier used in code, the user-facing word per locale, one sentence of meaning, and the words it must **not** be confused with. Rejected synonyms are the load-bearing part.
- **Written the moment a term is resolved, never batched.** A term settled during `/spec` and written down after the feature ships is a term three agents already got wrong.
- Meaning only. Requirements, behavior, and implementation belong to the spec — a glossary entry that describes what happens when you tap something is a spec leaking into the wrong file.
- Only project-specific vocabulary. Not `Widget`, not `Provider`, not general Flutter or Dart terms.
- Terminology in the codebase disagreeing with this file is a review finding, not a cleanup task for later.

### `solutions/` categories — this list is the source of truth

`/compound` and `/fix` pick exactly one. Subfolders are created on demand; do not invent a category outside this list.

| Category | Use for |
|---|---|
| `bug-fixes` | Root-caused bugs: symptom → cause → fix → regression test |
| `feature-delivery` | Features shipped end-to-end; what the shape of the work turned out to be |
| `refactors` | Restructuring and cleanup, including how it was staged |
| `performance` | Performance work with before/after numbers |
| `testing` | Testing strategy and infrastructure |
| `tooling` | CI/CD, build, environment lessons |
| `architecture` | Architectural decisions and the trade-offs behind them |
| `investigations` | Research and analysis that did not (yet) become code |
| `lessons` | Process and planning lessons that fit no category above |

File format: kebab-case descriptive name; content = Symptom / Context → Root cause or decision → What was done (files changed, regression test) → Rule for the future.

Do NOT put here: universal patterns (→ `ai_toolkit/`), feature specs (→ `ai_specs/`), TODOs, secrets/keys, anything already answered by `pubspec.yaml` or the code itself.

---

## 4. `ai_specs/` — specs & plans

### Structure and naming

Flat folder + `archive/`. Up to three files per feature, sharing the same number and name:

```
ai_specs/
  README.md                      # index (see below)
  019-item-photo-crop-ledger.md  # ledger: resolved Q/A behind the spec (L1, L2, …)
  019-item-photo-crop-spec.md    # spec: refined requirements
  019-item-photo-crop-plan.md    # plan: phased implementation
  archive/                       # completed features, moved as-is
    001-.....md
```

- `NNN` — zero-padded sequence number, **never reused**, one number = one feature. Next number = highest existing (including `archive/`) + 1.
- Name — short kebab-case, 2–4 words, noun-based (`item-photo-crop`, not `add-photo-cropping-to-items`).
- Suffixes are fixed: `-ledger`, `-spec`, `-plan` only. No other suffixes (`-impl`, `-feature`, `-fix` are not allowed).
- The original request is NOT a separate file — `/spec` records it verbatim in the spec body under `Source request`.
- Small fix may have only `NNN-name-spec.md` (with `type: fix`) and skip both the plan and the ledger.

### Spec size — S / M / L

A 16k-token spec for a 10-line change is the most common way this workflow wastes money, and the template is what makes it 16k. `/spec` picks a size and says which it picked:

| Size | When | Shape |
|---|---|---|
| **S** | bug or change ≤ ~50 lines, no new data model, no new route | no spec at all — `/fix` records a compact fix file |
| **M** | one screen or one behavior, existing data model, existing route | Goal · User Flow (happy + errors) · Requirements · Technical Constraints · Validation. No Background, no Non-functional, no Edge-case matrix unless one actually applies |
| **L** | new data model, new route, auth/permissions/payments, or 3+ phases expected | the full template |

Size is a claim that can be wrong in one direction only: an M spec that turns out to need a migration is upgraded to L before `/plan`, never after.

### YAML frontmatter (mandatory in every spec/plan file)

```yaml
---
title: Item photo crop
status: draft        # draft | refined | approved | in-progress | done
date: 2026-07-05
type: feature        # feature | fix | refactor
---
```

- `status` transitions: `draft` → `refined` (after adversarial review) → `approved` (human sign-off) → `in-progress` → `done`.
- No code changes until the spec is `approved`.
- Statuses live ONLY in frontmatter — never as plain-text lines in the body.

### Interview ledger — `NNN-name-ledger.md`

The spec is the requirements contract. The ledger is **why the contract says what it says**: the questions the agent asked, the answers the human gave, and what each answer decided.

Without it the chain of custody starts at the spec, and a decision made in chat but lost while writing the spec is unrecoverable — worse, invisible. `spec-conformance` proves code matches spec; nothing else proves spec matches what you said.

Format — one record per materially resolved question, stable ids in conversation order, never renumbered:

```markdown
---
title: Item photo crop
parent: 019-item-photo-crop-spec.md
date: 2026-07-05
---

## L1
Status: current
Question: Should a crop be re-editable after the item is published?
Answer: Yes, until the first order is placed against it.
Decision: Crop is editable while `order_count == 0`; read-only after.
Constraints:
- Do not re-crop the stored original — keep it for re-editing.

## L2
Status: deferred
Question: Should crops be generated server-side for old items?
Answer: —
Reason: Backfill decided separately; not part of this feature.
```

Rules:

- **Statuses:** `current` (active — must be covered by the spec) · `deferred` (intentionally unresolved — must appear in the spec's Out of Scope or as an open question).
- **Coverage is checked, not assumed.** Every `current` id appears inline in the spec, in the requirement it produced: `- [ ] R3: crop editable while order_count == 0. Verifiable by ... [L1]`.
- Include only decisions that change observable behavior, data shape, scope, or terminology. Not conversational turns, not restatements.
- One `current` record per question. A changed answer replaces the record; add an `Answer History:` list only when the earlier answer explains a constraint that survives.
- Never edit a ledger record to match a spec that drifted. The ledger records what was said; if the spec disagrees, the spec is wrong or the decision changed — and a changed decision is a new record.
- No ledger for `type: fix` specs and no ledger written retroactively to look complete. A feature with no interview gets one record for the source request, or no file at all.

### `archive/`

- When a feature reaches `status: done`: set the status, move all its files to `archive/`, update `README.md`.
- Files in `archive/` are read-only reference — never edit them.
- Active folder should contain only features currently in flight (target: 2–3).

### `README.md` index

A single table, maintained **by the agent as a rule**: whenever a spec is created, changes status, or is archived, the agent MUST update this table in the same session.

```markdown
| # | Feature | Type | Size | Status | Date | Files |
|---|---------|------|------|--------|------|-------|
| 019 | Item photo crop | feature | L | in-progress | 2026-07-05 | ledger, spec, plan |
| 018 | Refactor create offer flow | refactor | M | done (archived) | 2026-07-04 | spec, plan |
```

---

## 5. Agent workflow (mandatory)

1. **Read** this file, `ai_specs/README.md`, and the relevant `ai_toolkit/` + `ai_docs/` files (always `GLOSSARY.md` and `PROJECT.md`; plus `FIRESTORE_SCHEMA.md` / `CLOUD_FUNCTIONS.md` if data is involved). Check `ai_docs/solutions/` for lessons matching the task.
2. **Research** the existing code relevant to the request — do not assume.
3. **Spec**: pick the size (S/M/L), write `NNN-name-ledger.md` first, then create `NNN-name-spec.md` (`status: draft`). Ask the human about every hidden product decision (UX, persistence, edge cases) and record each resolved answer as an `L#` record. Requirements numbered (R1, R2…) with a "Verifiable by" criterion and the `[L#]` that produced them; edge cases numbered (E1, E2…). Resolve competing words against `GLOSSARY.md` and write new terms there immediately. Do not invent answers.
4. **Refine**: adversarially check the spec against the real codebase — wrong assumptions, package limitations, missing migrations, `current` ledger records the spec dropped or weakened, terminology drift. Fix the spec, set `status: refined`.
5. **Wait for approval** (`status: approved`) before writing the plan or code.
6. **Plan**: phased `NNN-name-plan.md`; each phase compiles, passes tests, and is committable on its own. Removal refactors: model change + consumer fixes = one atomic phase (see `solutions/lessons/`).
7. **Work**: implement phase by phase. After each phase: `flutter analyze`, run tests, commit.
8. **Compound & close**: capture new lessons into `ai_docs/solutions/`, update affected `ai_docs/` root files, set `status: done`, move spec files to `archive/`, update `README.md`.

Agent behavior rules:

- If a request conflicts with `ai_toolkit/` or `ai_docs/`, STOP and ask — do not silently deviate.
- If `ai_docs/` is missing needed information, ask the human, then add the answer to `ai_docs/` so it is never asked again.
- Never edit `ai_specs/archive/` or another feature's spec files.
- Never break a cross-reference: if a file mentioned in `ai_docs/` does not exist, create it or fix the reference — do not leave it dangling. If `ai_toolkit/` references a specific `ai_docs/` filename, that is a violation of the dependency rule — make the reference generic instead.

---

## 6. What every spec must answer

**App**
- Which providers/notifiers are created or changed; what stays ephemeral in widgets.
- Navigation changes: routes, deep links, guards.
- Loading / error / empty states for every new screen and async operation.
- All user-facing strings through l10n — no hardcoded strings.
- Which tests at which layer, per the project's testing doc.
- **Which test seam each new behavior is verified through** — the existing boundary where the nondeterministic or external part is replaced (repository override, fakes container, injected clock). Naming the seam is what prevents a new mock per feature; "we'll mock it" is not a seam.

**Backend**
- Exact document/row structure with field names and types → also reflected in the project's data-model doc.
- Access rules (Firestore rules / RLS policies) reviewed on every schema change, with a negative test per server-authoritative field.
- Indexes required by new queries; offline behaviour.
- Server functions: triggers, idempotency strategy, secrets handling.
- Migration plan for existing data when the schema changes.

The binding *how* for all of the above lives in `ai_toolkit/` (`RULES.md` → the relevant file). This section only lists what a spec is incomplete without.

---

## 7. Bootstrap checklist (new project)

Automated by the `/bootstrap` command; manual fallback:

- [ ] Copy `ai_toolkit/` from the toolkit as-is
- [ ] Copy this file to project root
- [ ] Create `ai_docs/` root files (even if short at first), including `GLOSSARY.md` seeded with the terms already visible in the code, + empty `solutions/{bug-fixes,tooling,lessons}/`
- [ ] Create `ai_specs/` with `README.md` (empty table) and `archive/`
- [ ] Reference this file in `CLAUDE.md` / `AGENTS.md`: "Read `spec-driven-rules.md` before any task"
