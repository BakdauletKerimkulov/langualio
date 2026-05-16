# Riverpod Guidelines

Universal Riverpod patterns for all Flutter projects. Use code generation (`@riverpod`) exclusively — never legacy `StateProvider`, `StateNotifierProvider`, or `ChangeNotifierProvider`.

---

## Provider Annotations

| Annotation | Use Case | Example |
|-----------|----------|---------|
| `@riverpod` (class) | Controllers with methods and mutable state | `SignInController`, `OrderListController` |
| `@riverpod` (function) | Computed values, streams, derived data | `filteredOffers`, `authStateChanges` |
| `@Riverpod(keepAlive: true)` (function) | Repositories, singletons, core streams | `authRepository`, `ordersRepository` |
| `@Riverpod(keepAlive: true)` (class) | Persistent state that survives screen transitions | `OnboardingFlow`, `CartState` |

**Rules:**
- Controllers are always auto-dispose (`@riverpod`) — they die with the screen
- Repositories and auth-related providers are always `keepAlive: true` — they live for the app session
- Never mix: a controller should not be `keepAlive`, a repository should not auto-dispose

## When to Create a Provider (and When NOT to)

**Create a provider for:**
- Data from backend (Firestore streams, API calls)
- Shared state across multiple widgets
- Business logic with side effects (auth, payments, orders)
- Computed/derived data from other providers

**Do NOT create a provider for:**
- UI-only state (expanded/collapsed, tab index, scroll position) — use local `StatefulWidget` state
- One-shot computations that don't need reactivity
- Constants or configuration values — use plain Dart constants
- Formatting/display logic — use extension methods on models

## State Classification Rule

Before creating a provider, ask: **"Who needs this data?"**

```
Data → Who needs it?
├── Most widgets  → App State       → Riverpod provider
├── Some widgets  → App State       → Riverpod provider
└── Single widget → Ephemeral State → local setState / StatefulWidget
```

**App State (→ Riverpod provider):**
- Auth status, user profile
- Fetched data (orders, offers, store info)
- Cart / selected items
- Filters that affect multiple screens
- Anything that persists across navigation

**Ephemeral State (→ local widget state):**
- Current tab index
- TextField input before submit
- Expanded/collapsed toggle
- Animation progress
- Scroll position
- "Show password" toggle

**Rule:** if only ONE widget reads and writes the state, it's ephemeral — use `StatefulWidget` or `useState`. Do NOT create a Riverpod provider for it.

---

## Controller Patterns

### Pattern 1: AsyncNotifier (fire-and-forget actions)

For operations that return success/failure to the widget (sign in, submit form, create order):

```dart
@riverpod
class SignInController extends _$SignInController {
  @override
  FutureOr<void> build() => null;

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (_mounted) state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      if (_mounted) state = AsyncError(e, st);
      return false;
    }
  }

  /// Check if this auto-dispose controller is still alive after awaits.
  bool get _mounted {
    try { state; return true; } catch (_) { return false; }
  }
}
```

### Pattern 2: Custom state notifier

For screens with complex UI state (multiple fields, loading substates):

```dart
@riverpod
class OrderListController extends _$OrderListController {
  @override
  OrderListState build() => const OrderListState();

  void setFilter(OrderFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> cancelOrder(String orderId) async {
    state = state.copyWith(cancellingOrderId: orderId);
    final result = await ref.read(ordersRepositoryProvider).cancel(orderId);
    if (!_mounted) return;
    switch (result) {
      Success() => state = state.copyWith(cancellingOrderId: null),
      Failure(:final error) => state = state.copyWith(error: error),
    }
  }

  bool get _mounted {
    try { state; return true; } catch (_) { return false; }
  }
}
```

### Pattern 3: Persistent state notifier

For state that must survive across screen transitions (onboarding flow, multi-step form, cart):

```dart
@Riverpod(keepAlive: true)
class OnboardingFlow extends _$OnboardingFlow {
  @override
  OnboardingState build() => const OnboardingState();

  void setBusinessName(String name) {
    state = state.copyWith(businessName: name);
  }

  void setStoreAddress(String address) {
    state = state.copyWith(storeAddress: address);
  }

  void reset() => state = const OnboardingState();
}
```

---

## Repository Providers

Repositories are functional providers with `keepAlive: true`. They encapsulate all data access (Firestore, APIs, local storage).

```dart
@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) throw const AppException.unauthenticated();

  return OrdersRepository(
    uid: user.uid,
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: kCloudFunctionsRegion),
  );
}
```

**Key rules:**
- Constructor injection for Firebase instances (testable)
- Throw loudly if auth prerequisite is missing — no silent fallback, no returning null
- Cloud Functions region is a constant defined in project config (not hardcoded in ai_toolkit)
- Repository watches `authStateChanges` — automatically invalidates when user signs out

---

## Stream Providers

For real-time Firestore data:

```dart
@riverpod
Stream<List<Order>> activeOrders(Ref ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchActiveOrders();
}
```

**Rules:**
- Auto-dispose by default — stream unsubscribes when no widget is listening
- Use `keepAlive: true` only for streams that must stay open app-wide (auth state)
- Never manually manage `StreamSubscription` in providers — Riverpod handles it

---

## ref.watch vs ref.read vs ref.listen

| Where | Method | Why |
|-------|--------|-----|
| `build()` method (controller or widget) | `ref.watch(...)` | Reactive — rebuilds when dependency changes |
| Action methods (button taps, form submits) | `ref.read(...)` | One-shot — no subscription needed |
| Side effects (snackbar, navigation, logging) | `ref.listen(...)` | Reacts to changes without rebuilding |

```dart
// In controller build() — reactive
@override
OrderListState build() {
  final orders = ref.watch(activeOrdersProvider);
  ref.onDispose(_cleanup);
  return OrderListState(orders: orders);
}

// In controller method — one-shot
Future<void> cancelOrder(String orderId) async {
  final repo = ref.read(ordersRepositoryProvider);
  await repo.cancel(orderId);
}
```

**Never use `ref.watch` inside async methods** — it creates subscriptions that cause unnecessary rebuilds and potential memory leaks.

---

## Widget Consumption

### ref.watch — reactive UI

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final ordersAsync = ref.watch(activeOrdersProvider);

  return ordersAsync.when(
    data: (orders) => OrderList(orders: orders),
    loading: () => const LoadingIndicator(),
    error: (e, st) => ErrorMessage(message: e.toString()),
  );
}
```

### ref.listen — side effects (snackbars, navigation)

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen(signInControllerProvider, (_, next) {
    next.whenOrNull(
      error: (e, st) => showErrorSnackbar(context, e.toString()),
    );
  });

  // ... rest of build
}
```

### Consuming controller state for button loading

```dart
final isLoading = ref.watch(signInControllerProvider).isLoading;

FilledButton(
  onPressed: isLoading ? null : () => _onSubmit(ref),
  child: isLoading
      ? const CircularProgressIndicator.adaptive()
      : const Text('Войти'),
);
```

---

## Error Handling in Providers

### Consistent `.when()` pattern

Create a reusable extension or helper for the common loading/error/data pattern:

```dart
// In widgets — always handle all three states
asyncValue.when(
  data: (data) => /* show data */,
  loading: () => /* show skeleton or spinner */,
  error: (e, st) => /* show error with retry */,
);
```

### Error types

Use typed exceptions (not raw strings) so widgets can show appropriate messages:

```dart
sealed class AppException implements Exception {
  const AppException();
  const factory AppException.unauthenticated() = UnauthenticatedException;
  const factory AppException.notFound(String resource) = NotFoundException;
  const factory AppException.server(String message) = ServerException;
}
```

---

## Lifecycle & Cleanup

Always register cleanup in `build()`, not in methods:

```dart
@override
SomeState build() {
  ref.onDispose(() {
    _timer?.cancel();
    _subscription?.cancel();
  });
  return const SomeState();
}
```

---

## Server State Sync

- **Do not** manually call `ref.invalidate()` after every mutation — prefer Firestore streams that auto-propagate changes
- Use `ref.invalidate(provider)` only when there is no stream (e.g. one-shot API calls that need refreshing)
- After a write operation, the Firestore stream listener will automatically emit the updated data

---

## Testing & Overrides

Providers are testable via `ProviderContainer` overrides:

```dart
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(MockAuthRepository()),
    ordersRepositoryProvider.overrideWithValue(MockOrdersRepository()),
  ],
);

// Use in widget tests
await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  ),
);
```

**Rules:**
- Repositories are the primary override point (swap real for mock)
- Never override controllers — test them by overriding their dependencies
- Use `ProviderContainer` in unit tests, `UncontrolledProviderScope` in widget tests

---

## Sealed Result Types

For complex operation outcomes where multiple distinct results are possible:

```dart
sealed class OrderResult {
  const OrderResult();
}

class OrderCreated extends OrderResult {
  const OrderCreated({required this.orderId, required this.qrCode});
  final String orderId;
  final String qrCode;
}

class OrderOutOfStock extends OrderResult {
  const OrderOutOfStock();
}

class OrderPaymentFailed extends OrderResult {
  const OrderPaymentFailed({required this.message});
  final String message;
}
```

Widget handles each case with pattern matching:

```dart
final result = await ref.read(orderControllerProvider.notifier).createOrder(offerId);

switch (result) {
  case OrderCreated(:final orderId) => context.push('/orders/$orderId'),
  case OrderOutOfStock() => showSnackbar('Товар закончился'),
  case OrderPaymentFailed(:final message) => showErrorDialog(message),
}
```

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| Using `ChangeNotifier`, `BLoC`, or raw `setState` for business logic | Riverpod `@riverpod` only |
| Creating monolithic state classes with 10+ fields | Split into focused providers |
| Using `ref.watch` inside async methods | Use `ref.read` in methods |
| Forgetting `_mounted` check after await in auto-dispose controllers | Always check before setting state |
| Putting business logic directly in widgets | Delegate to controller methods |
| Using legacy `StateProvider` / `StateNotifierProvider` | Use `@riverpod` code generation |
| Creating a provider for every piece of state | Use local widget state for UI-only concerns |
| Manually managing `StreamSubscription` in providers | Let Riverpod handle stream lifecycle |
| Hardcoding Firebase region in provider | Use a project constant from config |