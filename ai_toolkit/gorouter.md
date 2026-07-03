# GoRouter Navigation Guidelines

Universal GoRouter patterns for all Flutter projects. Project-specific route lists belong in `ai_docs/`.

---

## File Naming

| Condition | File name | Example |
|-----------|-----------|---------|
| Single app | `app_router.dart` | `lib/src/routing/app_router.dart` |
| Multiple apps in one repo | `{app}_router.dart` | `client_router.dart`, `business_router.dart` |

Place router files in `lib/src/routing/`.

---

## Route Enum

Define all route names as an enum. Never use raw strings for route names.

```dart
enum AppRoute {
  home,
  product,
  leaveReview,
  cart,
  checkout,
  orders,
  account,
  signIn,
  admin,
}
```

Use `name:` parameter in every `GoRoute`:

```dart
GoRoute(
  path: '/',
  name: AppRoute.home.name,
  builder: (context, state) => const HomeScreen(),
)
```

---

## Router Provider

Create the router as a Riverpod provider with codegen. Watch `authRepository` so the router reacts to auth changes.

```dart
@riverpod
GoRouter goRouter(Ref ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // auth-based redirect logic
    },
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges()),
    routes: [ /* ... */ ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
```

**Rules:**
- Always use `GoRouterRefreshStream` in `refreshListenable` to re-evaluate redirects on auth state changes
- Always use `NotFoundScreen` for `errorBuilder`
- Set `debugLogDiagnostics: true` during development

---

## GoRouterRefreshStream

A `ChangeNotifier` adapter that bridges a `Stream` to GoRouter's `refreshListenable`. Place in `lib/src/routing/go_router_refresh_stream.dart`:

```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

---

## Navigation Methods

| Method | Use case | Back button? |
|--------|----------|-------------|
| `context.goNamed(AppRoute.home.name)` | Replace current screen | No |
| `context.pushNamed(AppRoute.product.name, pathParameters: {'id': id})` | Push on top of stack | Yes |
| `context.pop()` | Return to previous screen | — |

```dart
// Replace — no back button
context.goNamed(AppRoute.home.name);

// Push — back button returns to previous screen
context.pushNamed(
  AppRoute.product.name,
  pathParameters: {'id': product.id},
);

// Push with extra data
context.pushNamed(
  AppRoute.orders.name,
  extra: OrderDetailArgs(order: order),
);
```

**Rules:**
- Always navigate by name (`goNamed`, `pushNamed`) — never by path string
- Never use `Navigator.push` or `Navigator.pop` — always use GoRouter methods
- Pass IDs via `pathParameters`, complex objects via `extra`

---

## Route Structure

Nest related routes as children. Use `pageBuilder` with `MaterialPage(fullscreenDialog: true)` for modal-style screens (cart, account, sign-in):

```dart
GoRoute(
  path: '/',
  name: AppRoute.home.name,
  builder: (context, state) => const ProductsListScreen(),
  routes: [
    GoRoute(
      path: 'product/:id',
      name: AppRoute.product.name,
      builder: (context, state) {
        final productId = state.pathParameters['id']!;
        return ProductScreen(productId: productId);
      },
      routes: [
        GoRoute(
          path: 'review',
          name: AppRoute.leaveReview.name,
          pageBuilder: (context, state) {
            final productId = state.pathParameters['id']!;
            return MaterialPage(
              fullscreenDialog: true,
              child: LeaveReviewScreen(productId: productId),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: 'cart',
      name: AppRoute.cart.name,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: ShoppingCartScreen(),
      ),
    ),
    GoRoute(
      path: 'account',
      name: AppRoute.account.name,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: AccountScreen(),
      ),
    ),
  ],
)
```

---

## Redirect Guards

Use `redirect` to control access based on auth state. Return `null` to allow navigation, or a path string to redirect.

```dart
redirect: (context, state) {
  final user = authRepository.currentUser;
  final isLoggedIn = user != null;
  final path = state.uri.path;

  if (isLoggedIn) {
    // Already signed in — don't show sign-in page
    if (path == '/signIn') return '/';
  } else {
    // Not signed in — block protected routes
    if (path == '/account' || path == '/orders') return '/';
  }
  return null; // allow navigation
},
```

**Rules:**
- Redirect logic lives in the router's top-level `redirect`, not in individual routes
- `refreshListenable` triggers re-evaluation — no need for manual redirect calls
- For role-based access (admin), check roles in redirect and block unauthorized paths

---

## Tab Navigation (StatefulShellRoute)

Preserves state across bottom navigation tabs:

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

## Typed Extras

Pass data between screens with typed argument classes. Add a redirect guard to handle missing extras (e.g. deep link without data):

```dart
class OrderDetailArgs {
  const OrderDetailArgs({required this.order});
  final Order order;
}

GoRoute(
  path: 'orders/:orderId',
  redirect: (_, state) => state.extra is OrderDetailArgs ? null : '/orders',
  builder: (_, state) {
    final args = state.extra! as OrderDetailArgs;
    return OrderDetailScreen(args: args);
  },
)
```

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---------|-----------------|
| `Navigator.push` / `Navigator.pop` | Use `context.goNamed()`, `context.pushNamed()`, `context.pop()` |
| Navigating by path string `context.go('/orders')` | Navigate by name `context.goNamed(AppRoute.orders.name)` |
| Raw strings for route names `name: 'home'` | Enum `name: AppRoute.home.name` |
| Missing `refreshListenable` | Always use `GoRouterRefreshStream(authRepo.authStateChanges())` |
| Missing `errorBuilder` | Always set `errorBuilder: (_, __) => const NotFoundScreen()` |
| Redirect logic scattered in individual routes | Centralize in router's top-level `redirect` |
| Forgetting `fullscreenDialog: true` for modal screens | Use `pageBuilder` with `MaterialPage(fullscreenDialog: true)` |
| Passing complex objects via path params | Use `pathParameters` for IDs, `extra` for objects |