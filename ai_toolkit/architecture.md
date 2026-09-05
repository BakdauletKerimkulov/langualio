# Flutter Architecture Guidelines

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

Universal Flutter architecture patterns. Project-specific details (routes, collections, models) belong in `ai_docs/`.

---

## Project Structure (Feature-First)

```
lib/
├── main.dart                     — entry point, backend init, error zone
├── src/
│   ├── app.dart                  — MaterialApp.router with GoRouter
│   ├── app_bootstrap.dart        — ProviderContainer setup
│   ├── constants/                — Sizes, Colors, Theme
│   ├── core/
│   │   ├── errors/               — AppException hierarchy, error mappers
│   │   ├── logging/              — AppLogger (wraps package:logging)
│   │   └── json/                 — Custom JSON converters (e.g. DateTimeConverter)
│   ├── common_widgets/           — Shared widgets (buttons, indicators, overlays)
│   ├── localization/             — String extensions, future intl setup
│   ├── routing/                  — GoRouter config, AppRoute constants, AppPhase
│   └── features/
│       └── feature_name/
│           ├── domain/           — Models (freezed), enums, value objects
│           ├── data/             — Repositories (remote/API/local), DTOs
│           ├── application/      — Controllers (AsyncNotifier), services, providers
│           └── presentation/     — Screens, widgets (no business logic)
│               └── widgets/      — Extracted sub-widgets
```

### Sub-features

When a feature grows complex, nest sub-features:

```
features/orders/
├── application/
├── data/
├── domain/
├── presentation/
└── features/
    ├── checkout/           — payment + confirmation flow
    ├── order_tracking/     — real-time status updates
    └── order_history/      — past orders list
```

Each sub-feature has its own domain/data/application/presentation layers.

---

## Layer Rules (Dependency Direction)

Layers have a strict import hierarchy. Violations cause tight coupling and untestable code.

```
presentation → application → domain ← data
                                ↑
                            core/errors
```

| Layer | Can import | Cannot import |
|-------|-----------|---------------|
| `domain/` | Only Dart core, `core/errors` | Nothing from `data/`, `application/`, `presentation/`, no backend SDK imports (`cloud_firestore`, `supabase_flutter`, …) |
| `data/` | `domain/` (to return domain models), backend SDK, HTTP packages | `application/`, `presentation/` |
| `application/` | `domain/`, `data/` (via Riverpod providers) | `presentation/`, Flutter widgets, `BuildContext` |
| `presentation/` | Everything above | — |

**The golden rule:** `domain/` is pure Dart. If you see `import 'package:cloud_firestore/...'` or `import 'package:supabase_flutter/...'` in a domain file — it's a violation. Backend SDK types (`Timestamp`, `GeoPoint`, `DocumentReference`, `PostgrestMap`) belong in `data/` layer only.

### Shared Utilities Across Layers

If a utility function is needed by both `data/` and `application/` layers, place it in `domain/` as a top-level function (e.g., `domain/quiz_day_util.dart`). Do not use `@visibleForTesting` on methods that other layers legitimately need — extract them instead. Domain utilities must remain pure Dart (no external package dependencies).

---

## Repository Pattern

Repositories live in `data/` and are the only layer that touches the backend SDK / APIs. They accept and return **domain models**, never raw maps or DTOs.

```dart
// data/orders_repository.dart
class OrdersRepository {
  const OrdersRepository({
    required this.uid,
    required this.dataSource,
  });

  final String uid;
  final OrdersDataSource dataSource; // backend SDK client, injected

  /// Watch active orders for current user (real-time stream)
  Stream<List<Order>> watchActiveOrders() {
    return dataSource
        .watchOrders(customerId: uid, statuses: const ['reserved', 'ready'])
        .map((rows) => rows
            .map((row) => OrderDto.fromJson(row).toDomain())
            .toList());
  }

  /// Create order via a server-side function (not a direct client write)
  Future<Order> createOrder({
    required String offerId,
    required int quantity,
  }) async {
    final result = await dataSource.callCreateOrder({
      'offerId': offerId,
      'quantity': quantity,
    });
    return OrderDto.fromJson(result).toDomain();
  }
}
```

Backend-specific versions of this repository (Firestore/Cloud Functions, Supabase/RPC) live in
`backends/firebase/firebase.md` and `backends/supabase/supabase.md`.

**Rules:**
- Constructor injection for backend clients (testable via mocks)
- Stream methods for real-time data (`watchX`), Future methods for one-shot reads (`fetchX`) and writes
- All raw-row → domain mapping happens inside the repository
- Never expose SDK types (`DocumentSnapshot`, `QuerySnapshot`, `PostgrestResponse`) or `Map<String, dynamic>` to application layer

---

## DTO ↔ Domain Mapping

DTOs (Data Transfer Objects) handle serialization. Domain models are clean Dart classes. The mapping lives in `data/` layer.

```dart
// data/order_dto.dart
@freezed
abstract class OrderDto with _$OrderDto {
  const OrderDto._();

  const factory OrderDto({
    required String id,
    @DateTimeConverter() required DateTime createdAt,
    @DateTimeConverter() required DateTime updatedAt,
    required String storeName,
    required String status,
    required int totalPrice,
  }) = _OrderDto;

  factory OrderDto.fromJson(Map<String, dynamic> json) => _$OrderDtoFromJson(json);

  /// Map DTO → Domain model
  Order toDomain() => Order(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    storeName: storeName,
    status: OrderStatus.values.byName(status),
    totalPrice: totalPrice,
  );
}
```

```dart
// domain/order.dart — pure Dart, no backend SDK imports
@freezed
abstract class Order with _$Order {
  const Order._();

  const factory Order({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String storeName,
    @Default(OrderStatus.reserved) OrderStatus status,
    required int totalPrice,
  }) = _Order;

  bool get isActive => status == OrderStatus.reserved || status == OrderStatus.ready;
  bool get canCancel => status == OrderStatus.reserved;
}
```

**Rules:**
- DTO has the serialization converters and backend-specific annotations — domain model does not
- DTO has `toDomain()` method. If you need to write back, add `static OrderDto fromDomain(Order order)`
- Domain model has computed getters for business logic (`isActive`, `canCancel`)
- Domain model never imports `cloud_firestore`, `supabase_flutter`, `json_annotation`, or any external package

---

## Application Services

The `application/` layer holds two kinds of classes:

| Kind | When | Example |
|------|------|---------|
| **Controller** (`AsyncNotifier`) | State owned by one screen; widget triggers actions | `SignInController`, `OrderListController` |
| **Service** (plain class with `Ref`) | Logic spanning multiple repositories or reacting to app-wide events; no screen owns it | `CheckoutService`, `CartSyncService` |

### Service pattern — orchestrating repositories

A service coordinates multiple repositories behind one method the controller calls:

```dart
class CheckoutService {
  const CheckoutService(this.ref);
  final Ref ref;

  Future<OrderID?> placeOrder() async {
    final cart = await ref.read(cartRepositoryProvider).fetchCart();
    final order = await ref.read(ordersRepositoryProvider).create(cart);
    await ref.read(cartRepositoryProvider).clear();
    return order.id;
  }
}

@riverpod
CheckoutService checkoutService(Ref ref) => CheckoutService(ref);
```

### Reactive listener service

A `keepAlive` service that reacts to app-wide state changes (auth, connectivity) with `ref.listen`. It has no public methods — it's initialized once at bootstrap so its listener is active for the whole session:

```dart
class CartSyncService {
  CartSyncService(this.ref) {
    ref.listen<AsyncValue<AppUser?>>(authStateChangesProvider, (previous, next) {
      final previousUser = previous?.value;
      final user = next.value;
      if (previousUser == null && user != null) {
        _moveItemsToRemoteCart(user.uid); // local cart → remote on sign-in
      }
    });
  }
  final Ref ref;

  Future<void> _moveItemsToRemoteCart(UserID uid) async {
    try {
      // read local cart, merge into remote, clear local
    } catch (e, st) {
      ref.read(errorLoggerProvider).logError(e, st); // never rethrow — background work
    }
  }
}

@Riverpod(keepAlive: true)
CartSyncService cartSyncService(Ref ref) => CartSyncService(ref);

// app_bootstrap — initialize so the listener starts
container.read(cartSyncServiceProvider);
```

**Rules:**
- Services never import Flutter widgets or `BuildContext` — same restriction as controllers
- Reactive services are `keepAlive: true` and read once in `app_bootstrap` — otherwise the listener never starts
- Background work catches its own errors and logs them — an unawaited throw crashes nothing visibly and vanishes
- Controller = screen-owned state + actions; Service = cross-cutting orchestration. A controller may call a service; a service never touches a controller

---

## Navigation

Routing lives in `lib/src/routing/` and is owned by **`gorouter.md`** — route enum, named navigation, router provider, redirect guards, typed extras, tab shells. Read it before touching a route.

The one rule that belongs here, because it is a layer rule: navigation is a `presentation/` concern. `application/` and below never navigate and never touch `BuildContext`; a controller returns a result, the widget decides where to go.

**Never use `Navigator.push` / `Navigator.pop`** — always GoRouter, always by name.

### AppPhase — app-state-driven redirects

When redirects depend on more than auth (onboarding, forced update, maintenance), model the app's state as one enum instead of chaining boolean checks in `redirect`:

```dart
enum AppPhase { loading, unauthenticated, onboarding, ready }
```

The router reads it via `ref.read(appPhaseProvider)` and returns a destination per phase. Full redirect wiring → `gorouter.md` → Redirect Guards.

---

## Code Generation

### Packages

| Package | Purpose | Output |
|---------|---------|--------|
| `freezed` | Immutable models with copyWith/equality | `.freezed.dart` |
| `json_serializable` | JSON serialization | `.g.dart` |
| `riverpod_generator` | Provider code generation | `.g.dart` |

### Commands

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (during development)
dart run build_runner watch --delete-conflicting-outputs
```

### Freezed model pattern

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
abstract class Order with _$Order {
  const Order._();

  const factory Order({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String storeName,
    @Default(OrderStatus.reserved) OrderStatus status,
    required int totalPrice,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  bool get isActive => status == OrderStatus.reserved || status == OrderStatus.ready;
}
```

### Custom JSON converters

Backends serialize dates differently (Firestore `Timestamp`, ISO-8601 `timestamptz` strings). Wrap that difference in a converter used by DTOs only:

```dart
class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String value) => DateTime.parse(value);

  @override
  String toJson(DateTime dt) => dt.toIso8601String();
}

// Usage in DTO (not domain model)
@DateTimeConverter() required DateTime createdAt,
```

The Firestore `Timestamp` variant lives in `backends/firebase/firebase.md`.

### Rules

- **Never edit `.g.dart` or `.freezed.dart` files** — regenerate with build_runner
- After changing annotated sources, always run build_runner before testing
- Use `explicit_to_json: true` in `build.yaml` for nested object serialization
- Converters belong on DTOs, not domain models

---

## App Bootstrap

### Initialization order

```dart
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Backend SDK init (see backends/*.md for the concrete call)
    await initBackend();

    // 2. Crash reporting (platform-guarded)
    if (!kIsWeb) {
      FlutterError.onError = crashReporter.recordFlutterFatalError;
    }

    // 3. Local/emulator config (if enabled)
    if (useLocalBackend) await connectToLocalBackend();

    // 4. Create ProviderContainer
    final container = ProviderContainer(observers: [...]);

    // 5. Run app with UncontrolledProviderScope
    runApp(UncontrolledProviderScope(container: container, child: const App()));
  }, (error, stack) {
    // Top-level error handler
  });
}
```

### Startup widget pattern

Block UI until critical async work completes:

```dart
class AppStartupWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    return startup.when(
      data: (_) => const App(),
      loading: () => const SplashScreen(),
      error: (e, _) => AppStartupError(message: e.toString()),
    );
  }
}
```

---

## Environment Config (envied)

Use `envied` for compile-time, type-safe environment variables instead of parsing `.env` at runtime — typos fail the build, not production, and values are obfuscated in the binary:

```dart
// lib/src/core/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'STRIPE_PUBLISHABLE_KEY')
  static final String stripePublishableKey = _Env.stripePublishableKey;
}
```

**Rules:**
- `.env` stays in `.gitignore`; commit a `.env.example` with empty values
- `obfuscate: true` for anything secret-ish (still not truly secret on client — real secrets live in Cloud Functions)
- After changing `.env` or `env.dart`, rerun build_runner

---

## Platform Guards

Always wrap platform-specific APIs with `kIsWeb` checks:

```dart
import 'package:flutter/foundation.dart';

// Crash reporting (not supported on web by most SDKs)
if (!kIsWeb) {
  crashReporter.recordError(error, stack);
}

// Platform.isIOS (only safe AFTER kIsWeb check)
if (!kIsWeb && Platform.isIOS) {
  // iOS-specific code
}
```

**Rule:** Never call `Platform.isIOS` / `Platform.isAndroid` without first checking `kIsWeb` — it throws on Web.

---

## Error Handling

### Exception hierarchy

```dart
abstract class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;
  String get code;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error']);
  @override String get code => 'network';
}

class ServerException extends AppException {
  const ServerException(super.message);
  @override String get code => 'server';
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
  @override String get code => 'not_found';
}

class ValidationException extends AppException {
  const ValidationException(super.message);
  @override String get code => 'validation';
}

class UnauthenticatedException extends AppException {
  const UnauthenticatedException([super.message = 'Not authenticated']);
  @override String get code => 'unauthenticated';
}
```

This is the **only** `AppException` hierarchy. Do not declare a parallel one per feature or per layer — `riverpod.md` and the backend files reference this one.

### Backend error mapping

Map backend SDK errors to typed exceptions **in the data layer** — nothing above `data/` should ever see an SDK exception:

```dart
class ErrorMapper {
  static AppException map(Object error) => switch (error) {
    AppException() => error,
    // backend-specific branches live in the backend's mapper
    _ => NetworkException('Unknown error: $error'),
  };
}
```

Concrete mappers: `FirebaseErrorMapper` in `backends/firebase/firebase.md`, the
`PostgrestException` / `AuthException` mapper in `backends/supabase/supabase.md`.

### In controllers — AsyncValue pattern

```dart
state = const AsyncLoading();
final newState = await AsyncValue.guard(() => repo.doSomething());
if (mounted) state = newState;  // `mounted` from NotifierMounted mixin — see riverpod.md
```

Use try/catch on `AppException` only when the controller must branch on the exception type.

---

## Localization

The project uses ARB-based localization via `flutter gen-l10n`. Config: `l10n.yaml`, template: `app_en.arb`, output class: `AppLocalizations`.

Access strings via the `context.loc` extension from `lib/src/localization/string_hardcoded.dart`:
```dart
Text(context.loc.favorites)
Text(context.loc.addedToFavorites(storeName))  // parameterized
```

**Rules:**
- All user-visible strings go in ARB files (`lib/l10n/app_en.arb`, `app_ru.arb`, `app_kk.arb`)
- Access via `context.loc.keyName` — never inline Russian/Kazakh strings in Dart code
- After adding/changing ARB keys, run `flutter gen-l10n` (or let `flutter build` auto-generate)
- Code and comments remain in English
- Legacy `.hardcoded` extension still exists but is deprecated — migrate to `context.loc` when touching affected files

---

## Logging

Wrap `dart:developer` `log()` in a project-level `AppLogger` class for consistent tagging and crash-reporting forwarding:

```dart
final _log = AppLogger('OrdersRepository');

_log.fine('Fetching orders for user $uid');          // Debug only
_log.info('Order created: $orderId');                // Informational
_log.warning('Retry attempt $n', error: e);          // Recoverable
_log.error('Payment failed', error: e, stackTrace: st); // → crash reporting
```

**Rules:**
- Never use `print()` (see `code_style.md` → Prohibited Patterns)
- Use `AppLogger` (wraps `dart:developer` `log()`) or `debugPrint()` as fallback
- One logger per class/file with descriptive tag name
- Errors auto-forward to the crash-reporting service in release (non-Web)

---

## Testing

см. `testing.md` — test pyramid per layer, structure, Robot pattern, golden tests, backend tests and CI gates.

---

## Local Data alongside Remote

When a feature mixes remote (backend) and local (drift, bundled assets) sources, split the data layer explicitly:

```
features/{name}/data/
├── remote/   — remote backend repositories, DTOs
└── local/    — drift tables/DAOs, asset loaders
```

- One repository per source; if the feature needs a merged view, compose them in an `application/` service — never inside one repository that secretly juggles both.
- Domain models stay source-agnostic: no drift row classes or raw backend row types above `data/`.
- Decide and document the source of truth per entity (e.g., learning progress = server; bundled word list = asset; user-added words = local until synced). Sync/conflict logic lives in `application/`, is explicit, and is covered by tests.
- Client-generated IDs for offline-created rows: UUIDs generated once, reused on sync — never re-keyed.

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| One repository mixing local (drift) and remote calls | Split `data/local` + `data/remote`, compose in application service |
| Backend SDK imports in `domain/` | Domain is pure Dart — SDK types stay in `data/` |
| Returning `Map<String, dynamic>` from repository | Return typed domain models |
| JSON converters on domain models | Put them on DTOs only |
| Business logic in widgets | Delegate to controllers in `application/` |
| `Navigator.push` / `Navigator.pop` | Use GoRouter: `context.go()`, `context.push()`, `context.pop()` |
| Editing `.g.dart` or `.freezed.dart` | Regenerate with `build_runner` |
| `Platform.isIOS` without `kIsWeb` check | Always check `kIsWeb` first |
| `print()` for debugging | `AppLogger` or `debugPrint()` |
| Monolithic 500+ line screen files | Extract widgets, move logic to controllers |
| Hardcoded colors, sizes, text styles | Use `AppColors`, `Sizes`, `Theme.of(context)` |