# Command Conventions

Shared behaviour for every slash command in this toolkit. Commands reference this file instead of restating it. On conflict with a command, the command wins for its own specifics; on conflict with `spec-driven-rules.md`, that file wins.

---

## C1 — Layout check

Commands that touch specs, plans, or code first verify the project root has:

- `ai_specs/` — specs and plans
- `ai_toolkit/` — the binding stack contract
- `ai_docs/` — project knowledge

Missing `ai_specs/` when a command needs it → **stop**, suggest `/bootstrap`. Missing `ai_toolkit/` or `ai_docs/` → warn that the result will lack stack/codebase context, then continue.

Commands that run git → `git rev-parse --git-dir 2>/dev/null` must succeed, else stop.

## C2 — Reading the toolkit

`ai_toolkit/` is the **binding source of truth** for how code is written. Its rules override your defaults, your habits, and anything an existing file happens to do differently.

**Always read, in full:**
- `ai_toolkit/RULES.md` — the binding rule index (~2k tokens)
- `ai_toolkit/RULES-backend.md` — the same for the project's backend

**Then read the full source file for every area you actually touch.** `RULES.md` tells you that a rule exists and where it lives; the full file tells you how to apply it. Touching providers → `riverpod.md`. Writing tests → `testing.md`. Adding a route → `gorouter.md`. Changing schema, rules, or a server function → the backend file. Reviewing a diff → every file the diff touches the area of.

Do not write code in an area whose source file you have not read. Do not skip `RULES.md` because you read it in a previous session — each command run starts fresh.

If a rule cannot be followed, or you are tempted to deviate: **stop and ask** (state the rule, the conflict, your proposed alternative). Silent deviation is a run failure, not a judgement call.

## C3 — Resolving a spec or plan from `$ARGUMENTS`

In this order:

1. **Valid file path** → load it.
2. **Prefix or fragment** (`003`, `auth`, `003-auth`) → glob `ai_specs/` for `*-spec.md` / `*-plan.md` as appropriate. Unique match → use it. Multiple → list and ask via `AskUserQuestion`.
3. **Empty** → list the 4 most recently modified candidates (`ls -lt`), ask via `AskUserQuestion`. If more than 4 exist, say the total so the user knows the picker is partial.

Nothing resolves → stop and report what you tried. Once resolved, print the exact path.

## C4 — Numbering and naming

Per `spec-driven-rules.md` § 4:

- `{NNN}-{feature-name}-ledger.md`, `{NNN}-{feature-name}-spec.md`, `{NNN}-{feature-name}-plan.md`. Only `-ledger`, `-spec` and `-plan` suffixes exist.
- `NNN` = highest existing prefix across `ai_specs/` **and** `ai_specs/archive/`, plus one. Numbers are never reused. Both empty → `001`.
- Updating an existing feature → reuse its prefix.
- Name: short kebab-case, 2–4 words, noun-based (`item-photo-crop`, not `add-photo-cropping-to-items`).

## C5 — Status and index

- `status` lives **only** in YAML frontmatter, never as body text: `draft → refined → approved → in-progress → done`.
- No code is written for a spec that is not `approved` or `in-progress`.
- Any command that creates a ledger/spec/plan, changes a status, or archives a feature **must** update the `ai_specs/README.md` table in the same run. Columns: `# | Feature | Type | Size | Status | Date | Files`.

## C6 — Stack

These projects are Flutter + Riverpod + GoRouter, with Firebase or Supabase as the backend. Commands, lint, and test invocations come from `ai_toolkit/` and the project's `scripts/gate.sh` — never from a guess about which language this is.

## C7 — Asking

Ask via `AskUserQuestion`, in **one batch, at most 4 questions**. Ask only about things you cannot decide from code + `ai_toolkit/` + `ai_docs/`: product decisions, UX choices, business rules, scope boundaries, priority trade-offs. Never ask about anything the toolkit, the docs, or the codebase already answers. If nothing qualifies, ask nothing and state your assumptions instead — do not invent questions to fill a quota.

## C8 — Honest reporting

- Never mark a task `[x]` that is not done and validated.
- A blocked run that says so is a useful result; a green run built on a weakened check is worse than a failure, because it hides one.
- Never weaken, skip, or delete a test to make a check pass. If a test is genuinely wrong, stop and ask.

## C9 — Interview ledger

Defined in `spec-driven-rules.md` § 4. What every command needs to know:

- The ledger (`{NNN}-{name}-ledger.md`) records the **resolved questions behind the spec**, one `L#` record each, statuses `current` / `deferred`.
- Commands that **write** a spec write the ledger first, then reference `[L#]` inline in the requirement each record produced.
- Commands that **read** a spec read the sibling ledger when it exists. A `current` record with no `[L#]` anywhere in the spec is a finding, not a formatting detail: it is a decision the human made and the spec silently dropped.
- Never edit a ledger record to agree with a spec that drifted, and never write records retroactively so coverage looks complete. Missing coverage is reported, not manufactured.
- No ledger for `type: fix`.

## C10 — Domain vocabulary

`ai_docs/GLOSSARY.md` is the canonical vocabulary (`spec-driven-rules.md` § 3).

- Read it in Step 1 of any command that writes a spec, a plan, or code. It is short; there is no excuse for not having it.
- Use its canonical term, in code and in user-facing strings. Two words for one concept in the same diff is a review finding.
- A term resolved during a run is written to `GLOSSARY.md` **in that run**, not batched for later.
- A term in the glossary that the codebase contradicts → surface it; do not silently adopt whichever word the code happens to use.

## C11 — Orchestrated mode

A command invoked by an orchestrator (`/ship`) instead of a human runs with **no one to ask**. When a command detects it is dispatched as a subagent, or is passed `--orchestrated`:

- `AskUserQuestion` is unavailable. A question that would have been asked becomes a recorded artifact: an assumption in the spec, a `deferred` ledger record, or a `blocking` finding — never a guess presented as a decision.
- Findings go to `.gate/reviews/{command}.json` as well as chat, because the orchestrator reads files, not prose.
- **Only `blocking` findings may be auto-applied.** `major` and below are reported upward for the human gate. An orchestrated command that silently rewrites an artifact on a `major` finding has removed the human's only chance to disagree.
- The report says explicitly that the run was orchestrated and which decisions were made without a human.
