---
title: Consolidate auth into repository, drop Notifier
date: 2026-07-23
work_type: refactor
tags: [auth, riverpod, repository, supabase, gorouter, state-management]
confidence: medium
references: [f98e2c5]
---

## Summary
Deleted `AuthNotifier` (application layer) and consolidated all auth logic into `AuthRepository` (data layer). Screens switched from watching a Riverpod Notifier to using local `setState` for loading/error, relying on GoRouter's `refreshListenable` + `redirect` for navigation on auth state change. Net result: −216 lines, simpler auth flow, one fewer provider.

## Reusable Insights

- **GoRouter redirect already handles auth navigation** — when `refreshListenable: GoRouterRefreshStream(repo.authStateChanges())` is wired up, screens don't need `ref.listen` to navigate on sign-in/sign-out. The router's `redirect` callback fires automatically. _Example: `app_router.dart:54`._
- **Loading/error state for one-shot actions belongs in the widget** — per `riverpod.md` "single widget → local StatefulWidget state", auth forms that only need `_isLoading` and `_error` don't require a Notifier. `setState` in a try/catch/finally is sufficient and avoids an extra provider layer.
- **Repository methods should not catch exceptions** — per `architecture.md`, the data layer propagates errors upward. Error-to-user-string mapping (`AuthException` → Russian message) belongs in the presentation layer, not the repository.
- **Check for duplicate auth wiring before adding a Notifier** — `auth_provider.dart` and `auth_repository.dart` both called `_client.auth.*` independently. The Notifier never consumed the Repository. Spotting this duplication early would have prevented the split-brain auth layer.

## Pitfalls

- **`signInWithPassword` missing email parameter** — symptom: sign-in silently failed. Cause: `auth_repository.dart` called `signInWithPassword(password: password)` without passing `email:`. Fix: add `email: email` to the call. Avoid by: always check required named parameters when wrapping SDK methods.
- **`currentSession` declared as `Stream<void>` instead of getter** — symptom: type error at call site. Cause: `_client.auth.currentSession` is a `Session?` getter, not a stream. Fix: change to `Session? get currentSession => _client.auth.currentSession;`. Avoid by: check the SDK type before wrapping — `onAuthStateChange` is the stream, `currentSession` is the snapshot.
