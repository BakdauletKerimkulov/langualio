# CLAUDE.md

Read these before any task:
1. `ai_toolkit/guidelines/` — all files (code style, architecture, riverpod, firebase, flutter)
2. `ai_docs/` — all files (project-specific knowledge base)

For feature work, follow the workflow:
1. Read `ai_specs/{feature}/requirements.md`
2. Generate plan with `ai_toolkit/commands/plan.md`
3. Implement with `ai_toolkit/commands/implement.md`
4. Review with `ai_toolkit/commands/review.md`
5. Commit with `ai_toolkit/commands/commit.md`

## Build & Dev Commands

### Flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
flutter run
flutter analyze
flutter test

### Supabase Edge Functions
cd supabase/functions
supabase functions serve   # local dev
supabase functions deploy <function-name>

### Supabase
supabase start             # local dev (Docker)
supabase stop
supabase db reset          # apply migrations from scratch
supabase migration new <name>
supabase db push           # apply pending migrations to remote