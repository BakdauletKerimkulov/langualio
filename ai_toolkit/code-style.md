# Code Style Guidelines

_Часть общей базы agentic-coding-toolkit. Правь в базе, не в проекте — локальные правки затрёт sync._

Universal rules for all Flutter projects. Project-specific conventions belong in `ai_docs/`.

---

## Linting & Static Analysis

Every project uses `flutter_lints` + `riverpod_lint` (via `custom_lint`). The default stock `analysis_options.yaml` is not enough — riverpod_lint catches provider mistakes (ref.watch in methods, missing dependencies, wrong provider types) automatically instead of relying on code review.

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
```

```yaml
# pubspec.yaml (dev_dependencies)
custom_lint: ^0.7.0
riverpod_lint: ^2.6.0
mocktail: ^1.0.0   # mocking in tests — no codegen needed
```

**Rules:**
- Run `dart run custom_lint` in addition to `dart analyze` — IDE shows both, CI must run both
- Never disable a riverpod_lint rule project-wide without a comment explaining why
- Generated files (`.g.dart`, `.freezed.dart`) are always excluded from analysis

---

## Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case` | `offer_list_screen.dart` |
| Classes | `PascalCase` | `OfferListScreen` |
| Variables / methods | `camelCase` | `pickupWindowStart` |
| Private fields | `_camelCase` | `_repository`, `_isLoading` |
| Constants | `camelCase` or `SCREAMING_SNAKE` for env | `defaultRadius`, `API_KEY` |
| Providers | auto from class → `camelCaseProvider` | `offerListControllerProvider` |
| Enums | `EnumName.camelCaseValue` | `OrderStatus.pickedUp` |

## File Naming Pattern

Project structure and feature layers are defined in `architecture.md`. This section covers only file naming:

- Screens: `{feature}_screen.dart`
- Controllers: `{feature}_controller.dart`
- Repositories: `{feature}_repository.dart`
- Services: `{what_it_does}_service.dart` / `WhatItDoesService`, located in `{feature}/application/` (e.g., cart service in a shop app → `cart_service.dart` / `CartService`)
- DTOs: `{model}_dto.dart`
- Domain models: `{model_name}.dart`
- Enums: `{enum_name}.dart`
- Widgets: descriptive name, `{what_it_is}.dart`

## Imports

- **Package imports** for cross-feature references: `import 'package:myapp/src/features/auth/domain/user.dart';`
- **Relative imports** only for sibling files within the same folder: `import 'order_status.dart';`
- Never use `../../../` chains — if you need to go up 3+ levels, use package import
- Group imports in order: dart → flutter → packages → project (with blank lines between groups)

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/src/features/orders/domain/order.dart';
import 'package:myapp/src/common/widgets/error_message.dart';
```

## File Size

- **Maximum 300 lines per file** — if a file exceeds this, decompose
- Screens should delegate logic to controllers, not contain business logic
- Extract widgets into separate files when they exceed ~80 lines or are reused

## Widgets

- **Never use private widget-methods** like `Widget _buildHeader()` — always extract a separate widget class
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for Riverpod access
- Use `super.key` syntax (not `Key? key`)
- All fields `final`, declared in the class body
- Prefer `const` constructors wherever possible

```dart
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.originalPrice,
    required this.discountedPrice,
  });

  final int originalPrice;
  final int discountedPrice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$originalPrice ₸',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
          ),
        ),
        gapW8,
        Text('$discountedPrice ₸'),
      ],
    );
  }
}
```

## Spacing & Design Tokens

- **Never use raw numbers** for padding/margin — use `Sizes.pX` constants
- Use pre-built gap widgets: `gapH12`, `gapW16`, etc.
- Colors: `AppColors.green500`, `AppColors.red400` (from a centralized palette)
- Text styles: from `Theme.of(context).textTheme`, never hardcode `TextStyle(fontSize: 16)`

```dart
// Good
Padding(padding: const EdgeInsets.all(Sizes.p16))

// Bad
Padding(padding: const EdgeInsets.all(16))
```

## Responsive / Adaptive Design

- **Never hardcode layouts for a specific screen size** — no `if (width == 375)`, no pixel-perfect positioning tuned to one device
- Use **Material 3 window size classes** as the single source of breakpoints:

| Class | Width | Typical device | Layout |
|-------|-------|----------------|--------|
| `compact` | < 600 | phone | single column, bottom nav |
| `medium` | 600–839 | tablet portrait, foldable | two columns / nav rail |
| `expanded` | ≥ 840 | tablet landscape, desktop, web | multi-column, permanent drawer |

- Define breakpoints once as constants — never scatter raw `600` / `840` through widgets:

```dart
abstract final class Breakpoints {
  static const double compact = 600;
  static const double expanded = 840;
}

enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize fromWidth(double width) => switch (width) {
    < Breakpoints.compact => WindowSize.compact,
    < Breakpoints.expanded => WindowSize.medium,
    _ => WindowSize.expanded,
  };
}
```

- Branch on window size class, not raw pixels — switch the widget type, don't scale one layout:

```dart
// Good — different widget per size class
Widget build(BuildContext context) {
  final size = WindowSize.fromWidth(MediaQuery.sizeOf(context).width);
  return switch (size) {
    WindowSize.compact => const OfferListView(),
    WindowSize.medium || WindowSize.expanded => const OfferGridView(),
  };
}

// Bad — pixel-tuned magic numbers inline
if (MediaQuery.sizeOf(context).width < 412) { ... }
```

- Use `MediaQuery.sizeOf(context)` (not `MediaQuery.of(context).size`) — rebuilds only on size changes
- Use `LayoutBuilder` when a widget adapts to its **parent's** constraints rather than the screen (e.g. a card that lives in both a list and a sidebar)
- Content widths: use the shared `ResponsiveCenter` widget (max content width + centering) instead of ad-hoc `ConstrainedBox` — and `ResponsiveSliverCenter` inside `CustomScrollView`. Its `maxContentWidth` default comes from the same `Breakpoints` class — never a separate constant

## State Classes

Hand-written immutable state when freezed is overkill (simple state with 2–4 fields):

```dart
@immutable
class SomeScreenState {
  const SomeScreenState({
    this.status = ScreenStatus.loading,
    this.errorMessage,
  });

  final ScreenStatus status;
  final String? errorMessage;

  SomeScreenState copyWith({
    ScreenStatus? status,
    String? errorMessage,
  }) => SomeScreenState(
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SomeScreenState &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, errorMessage);
}
```

For domain models with JSON serialization — use **freezed + json_serializable**.

## Enums

Dart enums have built-in `index`, `name`, and `values` properties. Never declare a field with these names in an enum — use `dbValue`, `label`, `displayName`, etc. instead. Declaring `index` causes `illegal_concrete_enum_member`.

Enums carry UI data via extensions — no switching on raw strings:

```dart
enum OrderStatus { reserved, ready, pickedUp, notPickedUp, cancelled }

extension OrderStatusUi on OrderStatus {
  Color get color => switch (this) {
    OrderStatus.reserved => AppColors.yellow500,
    OrderStatus.ready => AppColors.green500,
    OrderStatus.pickedUp => AppColors.gray400,
    OrderStatus.notPickedUp => AppColors.red400,
    OrderStatus.cancelled => AppColors.gray300,
  };

  String get label => switch (this) {
    OrderStatus.reserved => 'Забронирован',
    OrderStatus.ready => 'Готов к выдаче',
    OrderStatus.pickedUp => 'Выдан',
    OrderStatus.notPickedUp => 'Не забрали',
    OrderStatus.cancelled => 'Отменён',
  };
}
```

## Dart 3+ Patterns

- Use `switch` expressions (not statements) for exhaustive matching
- Use records for multi-return values
- Use `sealed class` for result types with pattern matching
- Prefer `const` constructors wherever possible

```dart
// Records
final (lat, lng) = getCoordinates();

// Sealed result type
sealed class Result<T> {
  const Result();
}
class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}
class Failure<T> extends Result<T> {
  const Failure(this.error);
  final String error;
}

// Pattern matching
switch (result) {
  Success(:final data) => showData(data),
  Failure(:final error) => showError(error),
}
```

## Error Handling

- **Never swallow exceptions** with empty catch blocks
- Exception hierarchy, backend error mapping, and AsyncValue patterns are defined in `architecture.md`
- One rule here: log errors with `debugPrint()` or `log()` from `dart:developer`, never `print()`

## Null Safety

- **Never use `!`** without a preceding null check or guaranteed non-null context
- Prefer `?.`, `??`, and pattern matching over force-unwrapping
- Use `required` for non-nullable parameters in constructors

```dart
// Bad
final name = user!.displayName!;

// Good
final name = user?.displayName ?? 'Unknown';

// Also good (pattern matching)
if (user case final user?) {
  final name = user.displayName;
}
```

## Async / Await

- **Always use `async/await`** — never use `.then()` chains
- **Never pass `BuildContext` across an async gap** — check `mounted` or restructure
- Cancel stream subscriptions in `dispose()`
- Use `ref.onDispose()` in Riverpod controllers to clean up

```dart
// Bad
fetchData().then((data) {
  Navigator.of(context).push(...);  // context may be stale
});

// Good
Future<void> onSubmit() async {
  final data = await fetchData();
  if (!context.mounted) return;
  context.push('/next');
}
```

## Prohibited Patterns

| Do NOT use | Use instead |
|-----------|-------------|
| `print()` | `debugPrint()` or `log()` from `dart:developer` |
| `dynamic` | Explicit types, `Object?`, or generics |
| `!` without null check | `?.`, `??`, pattern matching |
| `.then()` chains | `async/await` |
| `Widget _buildX()` methods | Extracted widget class |
| Raw numbers for spacing | `Sizes.pX`, `gapHX`, `gapWX` |
| Hardcoded `TextStyle` | `Theme.of(context).textTheme` |
| Hardcoded color values | `AppColors.xxx` |
| Raw breakpoint numbers / pixel-tuned layouts | `WindowSize.fromWidth()` + `Breakpoints` constants |
| `var` for public API | Explicit type annotations |

## Comments

- `///` doc comments on public classes and public methods
- `// ── Section Name ──` dividers in long files (e.g. controllers with multiple method groups)
- No comments for self-evident code — code should be self-documenting
- Code and comments in **English**
- UI strings in **Russian** (and Kazakh where applicable), extracted to localization

### ARB apostrophe rule
In ARB strings, use a single `'` for apostrophes in plain text. Only double it (`''`) inside ICU message patterns (`{count, plural, ...}`, `{gender, select, ...}`). A doubled `''` in a plain string produces a literal `''` in the output, not a single `'`.
```json
"greeting": "You're welcome",           // ✅ plain string → single '
"items": "{count, plural, =1{1 item's} other{{count} items''}}" // ✅ ICU → doubled ''
"wrong": "You don''t have any",         // ❌ produces "You don''t" in output
```