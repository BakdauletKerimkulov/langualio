---
title: Fix chat UnimplementedError from duplicate storage provider
status: done
date: 2026-07-16
type: fix
severity: S
references: []
---

## Symptom
Opening the chat screen crashes the app with `UnimplementedError (Must be overridden in ProviderScope)`. The error originates from `sharedPreferencesProvider` not being overridden for the provider chain used by `chatRepositoryProvider`.

## Root cause
Two duplicate `storage_provider.dart` files exist: `core/local_storage/storage_provider.dart` (overridden in bootstrap) and `core/storage/storage_provider.dart` (never overridden). `chat_repository.dart` imported from the wrong path (`core/storage/`), so its `localStorageProvider` resolved to the un-overridden `sharedPreferencesProvider` which throws `UnimplementedError` by design.

## Fix
- **Files changed:** `lib/src/features/chat/data/chat_repository.dart`
- **Failing test that catches the regression:** `test/src/features/chat/data/chat_repository_provider_test.dart::chatRepositoryProvider resolves without UnimplementedError`
- **`ai_toolkit/` rules applied:** `riverpod.md` (DI via providers), `architecture.md` (dependency direction)
- **Toolkit deviations:** none
- **One-paragraph description of the change:** Changed the import in `chat_repository.dart` from `core/storage/` to `core/local_storage/` so that the `localStorageProvider` and `sharedPreferencesProvider` used by the chat feature are the same ones overridden in `app_bootstrap_supabase.dart`.
