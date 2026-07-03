# Flutter Architecture Guidelines

Universal Flutter architecture patterns. Project-specific details (routes, collections, models) belong in `ai_docs/`.

---

## Project Structure (Feature-First)

```
lib/
├── main.dart                     — entry point, Firebase init, error zone
├── src/
│   ├── app.dart                  — MaterialApp.router with GoRouter
│   ├── app_bootstrap.dart        — ProviderContainer setup
│   ├── constants/                — Sizes, Colors, Theme
│   ├── core/
│   │   ├── errors/               — AppException hierarchy, error mappers
│   │   ├── logging/              — AppLogger (wraps package:logging)
│   │   └── json/                 — Custom JSON converters (e.g. TimestampConverter)
│   ├── common_widgets/           — Shared widgets (buttons, indicators, overlays)
│   ├── localization/             — String extensions, future intl setup
│   ├── routing/                  — GoRouter config, AppRoute constants, AppPhase
│   └── features/
│       └── feature_name/
│           ├── domain/           — Models (freezed), enums, value objects
│           ├── data/             — Repositories (Firestore/API/local), DTOs
│           ├── application/      — Controllers (AsyncNotifier), providers
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
| `domain/` | Only Dart core, `core/errors` | Nothing from `data/`, `application/`, `presentation/`, no Firebase imports |
| `data/` | `domain/` (to return domain models), Firebase, HTTP packages | `application/`, `presentation/` |
| `application/` | `domain/`, `data/` (via Riverpod providers) | `presentation/`, Flutter widgets, `BuildContext` |
| `presentation/` | Everything above | — |

**The golden rule:** `domain/` is pure Dart. If you see `import 'package:cloud_firestore/...'` in a domain file — it's a violation. Firebase types (`Timestamp`, `GeoPoint`, `DocumentReference`) belong in `data/` layer only.

### Shared Utilities Across Layers

If a utility function is needed by both `data/` and `application/` layers, place it in `domain/` as a top-level function (e.g., `domain/quiz_day_util.dart`). Do not use `@visibleForTesting` on methods that other layers legitimately need — extract them instead. Domain utilities must remain pure Dart (no external package dependencies).

---

## Repository Pattern

Repositories live in `data/` and are the only layer that touches Firebase/APIs. They accept and return **domain models**, never raw maps or DTOs.

```dart
// data/orders_repository.dart
class OrdersRepository {
  const OrdersRepository({
    required this.uid,
    required this.firestore,
    required this.functions,
  });

  final String uid;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  /// Watch active orders for current user (real-time stream)
  Stream<List<Order>> watchActiveOrders() {
    return firestore
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['reserved', 'ready'])
        .orderBy('reservedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => OrderDto.fromJson(doc.data()).toDomain())
            .toList());
  }

  /// Create order via Cloud Function (not direct Firestore write)
  Future<Order> createOrder({
    required String offerId,
    required int quantity,
  }) async {
    final result = await functions.httpsCallable('createOrder').call({
      'offerId': offerId,
      'quantity': quantity,
    });
    return OrderDto.fromJson(result.data as Map<String, dynamic>).toDomain();
  }
}
```

**Rules:**
- Constructor injection for Firebase instances (testable via mocks)
- Stream methods for real-time data (`watchX`), Future methods for one-shot reads (`fetchX`) and writes
- All Firestore → domain mapping happens inside the repository
- Never expose `DocumentSnapshot`, `QuerySnapshot`, or `Map<String, dynamic>` to application layer

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
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime updatedAt,
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
// domain/order.dart — pure Dart, no Firebase imports
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
- DTO has `@TimestampConverter()`, Firebase-specific annotations — domain model does not
- DTO has `toDomain()` method. If you need to write back, add `static OrderDto fromDomain(Order order)`
- Domain model has computed getters for business logic (`isActive`, `canCancel`)
- Domain model never imports `cloud_firestore`, `json_annotation`, or any external package

---

## GoRouter Navigation

### Route constants

```dart
abstract final class AppRoute {
  static const home = '/';
  static const signIn = '/sign-in';
  static const offers = '/offers';
  static const offerDetail = '/offers/:offerId';
  static const orders = '/orders';
  static const orderDetail = '/orders/:orderId';
  static const settings = '/settings';
}
```

### Navigation

```dart
// Replace current screen (no back button)
context.go(AppRoute.home);

// Push on top (back button returns)
context.push(AppRoute.offerDetail, pathParameters: {'offerId': offer.id});

// Push with extra data
context.push(AppRoute.orderDetail, extra: OrderDetailArgs(order: order));
```

**Never use `Navigator.push`** — always navigate via GoRouter.

### Typed extras

Pass data between screens with typed classes:

```dart
class OrderDetailArgs {
  const OrderDetailArgs({required this.order});
  final Order order;
}

GoRoute(
  path: 'orders/:orderId',
  redirect: (_, state) => state.extra is OrderDetailArgs ? null : AppRoute.orders,
  builder: (_, state) {
    final args = state.extra! as OrderDetailArgs;
    return OrderDetailScreen(args: args);
  },
)
```

### Redirect guards (AppPhase)

Control flow based on app state (auth, onboarding):

```dart
enum AppPhase { loading, unauthenticated, onboarding, ready }

redirect: (ctx, state) {
  final phase = ref.read(appPhaseProvider);
  final path = state.matchedLocation;

  return switch (phase) {
    AppPhase.unauthenticated => AppRoute.signIn,
    AppPhase.onboarding when !path.startsWith('/onboarding') => AppRoute.onboarding,
    AppPhase.ready when path == AppRoute.signIn => AppRoute.home,
    _ => null,
  };
}
```

### Tab navigation (StatefulShellRoute)

Preserves state across bottom nav tabs:

```dart
StatefulShellRoute.indexedStack(
  builder: (_, __, navigationShell) => ScaffoldWithNav(shell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/home', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/offers', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/orders', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/profile', ...)]),
  ],
)
```

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

### Custom JSON converters (for Firestore Timestamps)

```dart
class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp ts) => ts.toDate();

  @override
  Timestamp toJson(DateTime dt) => Timestamp.fromDate(dt);
}

// Usage in DTO (not domain model)
@TimestampConverter() required DateTime createdAt,
```

### Rules

- **Never edit `.g.dart` or `.freezed.dart` files** — regenerate with build_runner
- After changing annotated sources, always run build_runner before testing
- Use `explicit_to_json: true` in `build.yaml` for nested object serialization
- `TimestampConverter` belongs on DTOs, not domain models

---

## App Bootstrap

### Initialization order

```dart
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Firebase core
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // 2. Crashlytics (platform-guarded)
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    // 3. Emulator config (if enabled)
    if (useEmulators) await connectToEmulators();

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

## Platform Guards

Always wrap platform-specific APIs with `kIsWeb` checks:

```dart
import 'package:flutter/foundation.dart';

// Crashlytics
if (!kIsWeb) {
  FirebaseCrashlytics.instance.recordError(error, stack);
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
```

### Firebase error mapping

Map Firebase errors to typed exceptions in the data layer:

```dart
class FirebaseErrorMapper {
  static AppException map(Object error) => switch (error) {
    FirebaseAuthException(code: 'user-not-found') =>
      const NotFoundException('User not found'),
    FirebaseAuthException(code: 'wrong-password') =>
      const ValidationException('Wrong password'),
    FirebaseFunctionsException(:final code, :final message) =>
      ServerException(message ?? code),
    _ => NetworkException('Unknown error: $error'),
  };
}
```

### In controllers — AsyncValue pattern

```dart
state = const AsyncLoading();
try {
  await repo.doSomething();
  if (_mounted) state = const AsyncData(null);
} on AppException catch (e, st) {
  if (_mounted) state = AsyncError(e, st);
}
```

---

## Localization

Mark all user-visible strings with `.hardcoded` extension for future extraction:

```dart
extension StringHardcoded on String {
  String get hardcoded => this;
}

// Usage
Text('Загрузка...'.hardcoded)
```

**Rules:**
- UI strings are in the target language (Russian, Kazakh, etc.)
- Code and comments are in English
- All hardcoded strings must use `.hardcoded` — makes grep-based extraction trivial later

---

## Logging

Wrap `dart:developer` `log()` in a project-level `AppLogger` class for consistent tagging and Crashlytics forwarding:

```dart
final _log = AppLogger('OrdersRepository');

_log.fine('Fetching orders for user $uid');          // Debug only
_log.info('Order created: $orderId');                // Informational
_log.warning('Retry attempt $n', error: e);          // Recoverable
_log.error('Payment failed', error: e, stackTrace: st); // → Crashlytics
```

**Rules:**
- Never use `print()` (see `code_style.md` → Prohibited Patterns)
- Use `AppLogger` (wraps `dart:developer` `log()`) or `debugPrint()` as fallback
- One logger per class/file with descriptive tag name
- Errors auto-forward to Crashlytics in release (non-Web)

---

## Testing

### Structure mirrors `lib/`

```
test/
└── src/
    └── features/
        └── orders/
            ├── application/
            │   └── order_controller_test.dart
            ├── domain/
            │   └── order_model_test.dart
            └── data/
                └── orders_repository_test.dart
```

### Conventions

- `group()` for related tests
- Test domain models: defaults, copyWith, equality, computed getters
- Test controllers: state transitions, edge cases
- Test pure functions in core/ (business logic, validation, computation)
- Mock repositories for controller tests (never hit real Firestore in tests)
- No widget tests required unless UI is complex/critical

```dart
void main() {
  group('Order', () {
    test('defaults to reserved status', () {
      final order = Order(id: '1', createdAt: now, updatedAt: now, ...);
      expect(order.status, OrderStatus.reserved);
      expect(order.isActive, true);
    });

    test('canCancel is false when picked up', () {
      final order = Order(..., status: OrderStatus.pickedUp);
      expect(order.canCancel, false);
    });
  });
}
```

### Running tests

```bash
flutter test                          # all tests
flutter test test/path_test.dart      # single file
flutter test --name "specific test"   # by name
```

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| Firebase imports in `domain/` | Domain is pure Dart — Firebase types stay in `data/` |
| Returning `Map<String, dynamic>` from repository | Return typed domain models |
| `TimestampConverter` on domain models | Put it on DTOs only |
| Business logic in widgets | Delegate to controllers in `application/` |
| `Navigator.push` / `Navigator.pop` | Use GoRouter: `context.go()`, `context.push()`, `context.pop()` |
| Editing `.g.dart` or `.freezed.dart` | Regenerate with `build_runner` |
| `Platform.isIOS` without `kIsWeb` check | Always check `kIsWeb` first |
| `print()` for debugging | `AppLogger` or `debugPrint()` |
| Monolithic 500+ line screen files | Extract widgets, move logic to controllers |
| Hardcoded colors, sizes, text styles | Use `AppColors`, `Sizes`, `Theme.of(context)` |