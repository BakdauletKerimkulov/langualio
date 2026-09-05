# Binding Rules — Index

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

**Read this file in full. It is the binding contract.** Every rule below is enforceable; `→ file` points at the full explanation, examples, and edge cases.

**Read the full file when you work in its area.** Touching providers → read `riverpod.md`. Writing tests → `testing.md`. Adding a route → `gorouter.md`. Touching the backend → `RULES-backend.md` and its source file. A rule you are about to apply in code is a rule you read in full first — this index tells you *that* it exists and *where*, not everything you need to apply it correctly.

Stack: Flutter 3.41 / Dart 3.11, Riverpod codegen, GoRouter, Material 3. Project specifics (routes, collections, models, services) → `ai_docs/`, never here.

---

## Layers & structure → `architecture.md`

- Feature-first: `lib/src/features/{feature}/{domain,data,application,presentation}/`. Complex features nest sub-features with their own four layers.
- Import direction is one-way: `presentation → application → domain ← data`. Violations are review-blocking.
- `domain/` is **pure Dart**. No `cloud_firestore`, no `supabase_flutter`, no `json_annotation`, no Flutter. Backend SDK types (`Timestamp`, `GeoPoint`, `DocumentReference`, `PostgrestMap`) live in `data/` only.
- `application/` never imports Flutter widgets or `BuildContext`.
- Repositories live in `data/`, are the only layer touching the backend SDK, take clients by constructor injection, and return **domain models** — never `Map<String, dynamic>`, never SDK types.
- `watchX()` returns a Stream (realtime); `fetchX()` / writes return a Future.
- DTOs carry the serialization converters and `toDomain()`; domain models carry computed getters (`isActive`, `canCancel`) and no annotations.
- Utility needed by two layers → top-level pure function in `domain/`. Never `@visibleForTesting` to share across layers.
- Mixed local + remote feature: split `data/local/` + `data/remote/`, one repository per source, compose in an `application/` service. Document the source of truth per entity.
- Controller = screen-owned state + actions. Service = cross-cutting orchestration across repositories. A controller may call a service; a service never touches a controller.
- Reactive services (`ref.listen` on auth/connectivity) are `keepAlive: true` and must be read once in `app_bootstrap`, or the listener never starts. They catch and log their own errors — never rethrow from background work.
- Never edit `.g.dart` / `.freezed.dart`. Regenerate: `dart run build_runner build --delete-conflicting-outputs`.
- Env vars via `envied` (compile-time, `obfuscate: true`); `.env` gitignored, `.env.example` committed. Real secrets live server-side, never in the client.
- Never call `Platform.isIOS` / `Platform.isAndroid` without a preceding `kIsWeb` check — it throws on web.
- Error handling: `AppException` hierarchy (`NetworkException`, `ServerException`, `NotFoundException`, `ValidationException`), each with a `code`. Backend SDK errors are mapped to it **in `data/`** — nothing above `data/` ever sees an SDK exception. This hierarchy is defined once in `architecture.md`; other files reference it.
- All user-visible strings through ARB + `context.loc.keyName`. Never inline Russian/Kazakh in Dart. Code and comments in English.
- Logging via `AppLogger` (or `debugPrint`). Never `print()`.

## Code style → `code-style.md`

- `flutter_lints` + `riverpod_lint` via `custom_lint`. CI runs **both** `dart analyze` and `dart run custom_lint`. Never disable a riverpod_lint rule project-wide without a comment saying why.
- Naming: files `snake_case`, classes `PascalCase`, members `camelCase`, private `_camelCase`. Files: `{feature}_screen.dart`, `{feature}_controller.dart`, `{feature}_repository.dart`, `{model}_dto.dart`, `{what_it_does}_service.dart`.
- Package imports across features; relative imports only for siblings in the same folder. Never `../../../`. Group: dart → flutter → packages → project.
- **Max 300 lines per file.** Extract a widget into its own file past ~80 lines or on second use.
- **Never `Widget _buildX()` methods** — extract a widget class. `super.key`, all fields `final`, `const` constructors wherever possible.
- Never raw numbers for spacing (`Sizes.pX`, `gapHX`, `gapWX`), never hardcoded `TextStyle` (`Theme.of(context).textTheme`), never hardcoded colors (`AppColors.x`).
- Responsive: branch on Material 3 window size classes via `WindowSize.fromWidth()` + a single `Breakpoints` class. Never pixel-tuned layouts, never scattered raw `600`/`840`. `MediaQuery.sizeOf(context)`, not `MediaQuery.of(context).size`. `ResponsiveCenter` for content width, not ad-hoc `ConstrainedBox`.
- Enums: never declare a member named `index`, `name`, or `values` (compile error). UI data hangs off the enum via an extension with a `switch` expression — never switch on raw strings.
- Dart 3: `switch` expressions over statements, records for multi-return, `sealed class` for result types.
- Never `!` without a null check. Never `.then()` chains — `async/await`. Never pass `BuildContext` across an async gap without `context.mounted`. Never `dynamic`, never `var` for public API.
- Never swallow an exception with an empty catch.
- `///` on public classes and methods. No comments for self-evident code.
- ARB apostrophes: single `'` in plain strings, doubled `''` only inside ICU patterns.

## State management → `riverpod.md`

- `@riverpod` codegen **only**. Never `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`, BLoC, or `setState` for business logic.
- Controllers are auto-dispose (`@riverpod`); repositories and auth streams are `@Riverpod(keepAlive: true)`. Never invert this.
- **No provider for ephemeral state** — tab index, scroll position, expand/collapse, TextField input before submit, animation progress all stay in `StatefulWidget`. Test: if exactly one widget reads and writes it, it is ephemeral.
- Auto-dispose controllers use `with NotifierMounted` + `ref.onDispose(setUnmounted)` + `if (mounted)` before setting state after an await. Use the shared mixin from `utils/` — never a per-controller `_mounted` hack.
- Default to `state = await AsyncValue.guard(...)`. try/catch only when branching on a specific exception type.
- `ref.watch` in `build()`, `ref.read` in action methods, `ref.listen` for side effects. **Never `ref.watch` inside an async method.**
- Repository providers throw loudly when an auth prerequisite is missing — no silent null, no fallback.
- Never manually manage a `StreamSubscription` in a provider. Never permanent `keepAlive: true` on a **family** provider (leaks one instance per parameter) — use `ref.keepAlive()` + a `Timer` (default 30 s) when re-mount flicker is the problem.
- **Never `DateTime.now()`** in controllers, domain logic, or repositories — inject `currentDateBuilderProvider`. Allowed only in presentation for pure display, and inside the provider itself.
- Register cleanup in `build()` via `ref.onDispose`, never in methods.
- Widgets handle all three `AsyncValue` states (`data` / `loading` / `error`). One `AsyncErrorLogger` `ProviderObserver` at bootstrap — never per-screen error logging.
- Do not `ref.invalidate()` after every mutation — backend streams propagate on their own. Invalidate only where there is no stream.
- Tests override **repositories**, never controllers. `ProviderContainer` in unit tests, `UncontrolledProviderScope` in widget tests.
- Never hardcode a backend region/URL in a provider — project constant.

## Navigation → `gorouter.md`

- Routes are an **enum**; every `GoRoute` sets `name: AppRoute.x.name`. Never raw route-name strings.
- **Navigate by name only**: `context.goNamed(...)`, `context.pushNamed(...)`, `context.pop()`. Never by path string, never `Navigator.push` / `Navigator.pop`.
- IDs via `pathParameters`, objects via `extra` (typed args class + a `redirect` guard for the missing-extra / deep-link case).
- Router is a `@riverpod` provider watching `authRepository`, with `GoRouterRefreshStream` in `refreshListenable` and `errorBuilder` → `NotFoundScreen`. Both are mandatory.
- Redirect logic lives in the router's top-level `redirect`, not scattered across routes.
- Modal screens: `pageBuilder` with `MaterialPage(fullscreenDialog: true)`. Tabs: `StatefulShellRoute.indexedStack`.

## Framework → `flutter.md`

- Never generate deprecated APIs. Most common: `withOpacity()` → `withValues(alpha:)`, `color.opacity` → `color.a`, `headline*`/`bodyText*`/`caption`/`subtitle*` → M3 `TextTheme` names, `ThemeData.accentColor`/`.errorColor`/`.backgroundColor` → `colorScheme.*`, `FontWeight.index` → `.value`, `findChildIndexCallback` → `findItemIndexCallback`, `containsSemantics` → `isSemantics`/`matchesSemantics`.
- Material 3 is the default — do not set `useMaterial3: false`.
- Color assertions in tests use `isSameColorAs(...)`, not `==` (components are floating-point now).
- Variable fonts: `FontWeight`, not `FontVariation('wght', ...)`.
- Assume Impeller — no Skia workarounds. Do **not** upgrade to AGP 9.
- After any Flutter upgrade: `dart fix --apply` → `dart analyze` → `build_runner build`.
- Widget tests on screens using `context.loc` need `AppLocalizations.localizationsDelegates` in the harness.

## Testing → `testing.md`

- Per layer: `domain/` pure logic (no mocks) · `data/` **pure static mappers** tested without a client · `application/` `ProviderContainer` + mocked repositories (`mocktail`) · `presentation/` critical flows only, Robot pattern.
- **Seams are fixed, not invented per feature:** repository provider override · fakes container (`createFakesProviderContainer`) · `currentDateBuilderProvider` for the clock · extracted pure mapper · extracted server-function helper. A new seam needs a written reason; never mock the SDK client, never mock a controller.
- **A bugfix is not done without a regression test reproducing the bug.**
- `test/` mirrors `lib/`. Robots live in `test/src/`, mirroring `features/`; `integration_test/` imports them. Assertions (`expectX`) live in the robot — tests read as scenarios.
- Never hit a real backend in tests. Mock repositories, not the backend SDK client.
- Backend test minimum: migrations/rules replay from scratch; a **negative access test** per server-authoritative field (a write as an ordinary authenticated user must fail); contract tests per privileged function (anonymous rejected, double call idempotent).
- Test access rules as `anon` / `authenticated` — never as a superuser/admin role, which bypasses them.
- Golden tests are tagged `golden` and excluded from the default CI lane; baselines are OS-sensitive.
- CI gates every layer, not just Flutter: `flutter analyze && flutter test`, `dart run custom_lint`, backend migration replay, backend rule/RPC suite, server-function unit tests. Deploy only from green.

## Documentation sync → `docs-sync.md`

A change to the data model, a server function contract, or a route is **not complete** until the matching `ai_docs/` section is updated in the same change.

Domain vocabulary comes from `ai_docs/GLOSSARY.md`: one concept = one canonical identifier in code + one word per locale in the UI. A new durable term is written there in the same run it is resolved, not after the feature ships. Two words for one concept in a diff is a review finding.

---

<!-- digest-of: architecture.md code-style.md riverpod.md gorouter.md flutter.md testing.md docs-sync.md -->
<!-- Regenerate reminder: after editing any file above, re-check that its binding rules still appear here. `sync-toolkit.sh --check` warns when a source file changed but RULES.md did not. -->
