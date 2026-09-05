# CLAUDE.md

Langualio — a Flutter app for learning English (Russian UI, English content) on Supabase.

## Sources of truth — read before any task

- `spec-driven-rules.md` — folder structure, naming, sizes, statuses. Binding; wins on conflict.
- `ai_toolkit/RULES.md` — the binding rule index; read it in full before the first edit.
  Touching the backend adds `ai_toolkit/RULES-backend.md`. Both name the full file to
  read for the area you are about to touch — follow that pointer, do not work from the digest.
- `ai_docs/` — this project: `PROJECT.md` (tables, RPC contracts, routes, feature map),
  `GLOSSARY.md` (domain vocabulary), `solutions/` (past decisions; search before re-deciding).
- `ai_specs/README.md` — index of specs and their statuses.

## Hard rules

- **Git:** never run `git add`, `commit`, `push`, `merge`, `rebase`, `stash` or any mutating
  git command without explicit user permission. Allowed freely: `status`, `log`, `diff`,
  `branch`, `remote`, `checkout`, `switch`. Never `push --force`.
- `main` is push-protected — work on a branch, merge by PR. `commit` and `push` also require a
  valid gate approval; `.claude/hooks/guard-bash.sh` enforces both.
- No code changes without an approved spec (`status: approved`), except trivial fixes.
- Don't change public APIs, routes, tables, JSON field names, or access rules without an
  explicit request — each one breaks a client.
- No unrelated refactoring: don't reformat, rename, or restructure outside the task.
- For risky changes (auth, permissions, data model, quotas) propose options and trade-offs first.

## Process

- Read the related code before editing: usages, data flow, neighbouring layers.
- Unclear requirements → ask 1–2 questions, don't guess.
- Prefer small, reviewable diffs that compile and pass the gate.
- `/fix` for a bug or a change under ~50 lines · `/spec` → `/refine` → `/plan` → `/work` →
  `/review` → `/commit` for a feature · `/ship` to orchestrate the whole chain ·
  `/compound` to capture a lesson worth keeping.

## Definition of done

`./scripts/gate.sh` — the exit code is the only definition. `--fast` runs tier 0 only.

Tier 0: `dart format`, `flutter analyze --fatal-infos --fatal-warnings`, `dart run custom_lint`,
`flutter test`. Tier 1: `deno test` over Edge Functions, plus the RLS/RPC suite replayed against
a fresh `supabase db reset` — needs Docker.

Only a full green run writes `.gate/approved_sha`, and it is bound to a hash of the working
tree: edit one character afterwards and the approval is stale. `--fast` never writes one.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after changing annotated sources
flutter run

supabase start                    # local stack (Docker)
supabase db reset                 # replay migrations from scratch
supabase migration new <name>
supabase db push                  # apply to remote

cd supabase/functions && supabase functions serve
supabase functions deploy <function-name>
```

## Project specifics

- Local grants are stricter than production — see `ai_docs/PROJECT.md` → Supabase-схема before
  assuming a privilege exists in both.
- `.gate/`, `scripts/gate.sh`, `.claude/hooks/` and `ai_toolkit/` are human-owned: describe the
  change you want in words instead of editing them.
