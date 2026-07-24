# CLAUDE.md

Read these before any task:
1. `ai_toolkit/` — all files (code style, architecture, riverpod, supabase, edge-functions, testing, flutter, gorouter)
2. `ai_docs/` — all files (project-specific knowledge base)

For feature work, follow the workflow in `ai_toolkit/commands.md` (templates in `ai_toolkit/templates.md`):
1. Read `ai_specs/{feature}/requirements.md`
2. Generate plan with `/plan`
3. Implement with `/implement`
4. Review with `/review`
5. Commit with `/commit`

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