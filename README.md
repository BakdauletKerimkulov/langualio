# Langualio

English learning app with an AI tutor powered by Claude. Built with Flutter + Supabase.

Features: word quiz (multi-meaning model with spaced repetition), AI chat tutor, grammar exercises, level assessment, progress tracking (XP, streaks, daily goals).

## Local setup

### Prerequisites

- Flutter SDK 3.41+
- Supabase CLI
- Docker (for local Supabase)

### Run

```bash
# 1. Start local Supabase
supabase start

# 2. Apply migrations
supabase db reset

# 3. Install Flutter dependencies
flutter pub get

# 4. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 5. Run the app (pass your Supabase keys)
flutter run \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

### Edge Functions (local)

```bash
supabase functions serve
```

### Tests

```bash
flutter analyze
flutter test
```

## Documentation

- `ai_docs/PROJECT.md` — full project documentation (DB schema, edge functions, routing, architecture)
- `ai_toolkit/` — code style, architecture, and framework guidelines
- `ai_specs/` — feature specs and implementation plans
