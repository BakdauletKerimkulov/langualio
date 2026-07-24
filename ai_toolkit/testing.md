# Testing Guidelines

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

What to test at each layer, and what CI must gate. The usual gap is backend testing — database rules, RPC/SQL and server functions have the least coverage while containing the most critical logic (progress algorithms, rate limits, roles, money).

---

## Test Pyramid per Layer

| Layer | What to test | How |
|---|---|---|
| `domain/` | Pure logic: calculators, state machines, model invariants | Plain `flutter test`, no mocks needed |
| `data/` | Row/document → model mappers | Extract mapping into **pure static functions** (`Repository.mapToX(rows)`) and test those without a backend client |
| `application/` | Notifier flows: loading → data/error, guard clauses | `ProviderContainer` + mocked repositories (`mocktail`) |
| `presentation/` | Critical screens only: main user flow, auth forms | Widget tests via the Robot pattern; don't chase 100% |
| Database rules / RPC / SQL | Every privileged function; every rule or policy that guards server-authoritative fields | See "Backend tests" below |
| Server functions (Cloud Functions / Edge Functions) | Handler steps: 401/400/429/502 branches, happy path | Unit tests on extracted pure helpers + smoke requests against the local emulator |

Rules of thumb:

- Any algorithm worth putting on the server (streak chains, XP rules, pricing) is worth a test — it's the code you can't hotfix by shipping a new app build.
- Mappers stay pure so repositories need no integration tests to be trusted.
- A bugfix task is not done without a regression test reproducing the bug.

---

## Structure mirrors `lib/`

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
- Mock repositories for controller tests with `mocktail` (never hit a real backend in tests)
- Widget tests for critical user flows use the **Robot pattern** (below) — skip widget tests for trivial screens

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

---

## Robot pattern (widget & integration tests)

Encapsulate widget-test interactions in per-feature **robot** classes so the same steps drive both widget tests and `integration_test/` E2E flows. Robots express tests in user language (`tapAddToCart`, `expectOrderVisible`) instead of raw finders:

```
test/src/
├── robot.dart                        — composite Robot (pumps the app with fakes)
├── mocks.dart                        — shared mocktail mocks
└── features/
    └── orders/orders_robot.dart      — per-feature robot
```

```dart
// test/src/features/orders/orders_robot.dart
class OrdersRobot {
  OrdersRobot(this.tester);
  final WidgetTester tester;

  Future<void> openOrdersScreen() async {
    await tester.tap(find.byKey(const Key('menuOrders')));
    await tester.pumpAndSettle();
  }

  void expectOrderVisible(String storeName) {
    expect(find.text(storeName), findsOneWidget);
  }
}

// test/src/robot.dart — composite: one entry point, sub-robots per feature
class Robot {
  Robot(this.tester)
      : auth = AuthRobot(tester),
        orders = OrdersRobot(tester);
  final WidgetTester tester;
  final AuthRobot auth;
  final OrdersRobot orders;

  Future<void> pumpMyAppWithFakes() async {
    final container = await createFakesProviderContainer(addDelay: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
  }
}
```

```dart
// Widget test and integration test share the same robot API
testWidgets('reserve and pick up order', (tester) async {
  final r = Robot(tester);
  await r.pumpMyAppWithFakes();
  await r.auth.signInAsTestUser();
  await r.orders.openOrdersScreen();
  r.orders.expectOrderVisible('Test Store');
});
```

**Rules:**
- Robots live in `test/src/`, mirroring `features/`; `integration_test/` imports them from there
- The composite `Robot` pumps the app via the fakes container (`addDelay: false`) — E2E flows run without a real backend
- Assertions (`expectX`) live in robots too — tests read as scenarios, not finder soup

Screens using `context.loc` need localization delegates in the test harness — see `flutter.md` → Widget Tests with Localization.

---

## Golden tests

Screenshot-diff tests for key screens at multiple window sizes (this is also how responsive breakpoints get verified). Tag them so they can be run/excluded separately:

```yaml
# dart_test.yaml
tags:
  golden:
```

```dart
@Tags(['golden'])
library;

testWidgets('products list — phone and tablet', (tester) async {
  final r = Robot(tester);
  await r.golden.loadFonts();
  for (final size in const [Size(390, 844), Size(834, 1194)]) {
    await r.golden.setSurfaceSize(size);
    await r.pumpMyAppWithFakes();
    await expectLater(find.byType(MyApp),
        matchesGoldenFile('products_list_${size.width.toInt()}.png'));
  }
});
```

```bash
flutter test --update-goldens --tags golden   # regenerate baselines
flutter test --tags golden                    # run only goldens
flutter test --exclude-tags golden            # everything else (default CI lane)
```

Golden baselines are platform-sensitive — regenerate on the same OS that CI uses, or keep goldens out of CI.

---

## Backend Tests

Keep backend tests next to the backend definition (SQL test files, rules test suites) and run them against the local stack. Concrete commands per backend live in `backends/*.md`.

Minimum suite:

1. **Migration / rules replay** — applying every migration (or deploying rules) from scratch must pass, CI-gated.
2. **Negative access tests** — for each server-authoritative column/field, a test that a write **as an ordinary authenticated user fails**. A rule or policy without a negative test is a hope, not a guarantee.
3. **Server function contract tests** — call each privileged function as an authenticated user and as an anonymous one: anonymous must be rejected, authenticated gets correct results; idempotency: calling twice yields the same state.

For server functions (Cloud Functions / Edge Functions):

- Extract testable logic (validation, prompt building, response parsing) into pure functions in a shared module and cover them with unit tests.
- Keep a smoke script per function: no token → 401, bad input → 400, quota exceeded → 429, happy path → 200. Run it against the local runtime before every deploy.
- Never test against a paid production API in CI — stub the fetch or run the smoke manually.

---

## CI Gates

CI must gate all layers, not just Flutter:

```
flutter analyze && flutter test        # app: analyzer + unit/widget tests
dart run custom_lint                   # riverpod_lint checks (see code-style.md)
<backend migrations replay, local>     # schema/rules apply from scratch
<backend rule/RPC test suite>          # access control + contract tests
<server function unit tests>           # Deno test / jest, per backend
```

Deploy only from green CI. A failing backend test blocks a schema push or a function deploy the same way a failing widget test blocks the app.

---

## Running tests

```bash
flutter test                          # all tests
flutter test test/path_test.dart      # single file
flutter test --name "specific test"   # by name
dart run custom_lint                  # riverpod_lint checks (see code-style.md)
```

---

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Testing access rules as a superuser/admin role | Run them as an ordinary authenticated / anonymous user — privileged roles bypass the rules |
| Only happy-path tests for server functions | Negative tests first: anonymous call, missing auth, double call |
| Widget tests for every screen | Cover domain/data/backend rules first — highest risk per line |
| Mocking the backend SDK client in repository tests | Extract pure mappers instead; mock repositories one level up |
| Backend changes verified "by clicking in the app" | Scripted, repeatable smoke + rule tests |
| Hitting a real backend in tests | Fakes container + mocked repositories |
