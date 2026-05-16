# Flutter & Dart Framework Guidelines

Current versions and framework-specific rules. Updated May 2026.

---

## Current Versions

| Component | Version | Released |
|-----------|---------|----------|
| Flutter | 3.41.5 (stable) | May 2026 |
| Dart | 3.11.0 | February 2026 |
| Impeller | Default on iOS and Android (API 29+) | Stable since 3.38 |
| Material Design | Material 3 (default) | Default since 3.16 |

2026 stable release cadence: 4 stable releases per year with published branch cutoff dates.

---

## Deprecated APIs — Do NOT Use

AI must never generate code with these deprecated APIs. Use the replacement instead.

### Colors & Opacity

| Deprecated | Replacement | Since |
|-----------|-------------|-------|
| `color.withOpacity(0.5)` | `color.withValues(alpha: 0.5)` | 3.27 |
| `color.opacity` | `color.a` | 3.27 |
| `Color(0xFFRRGGBB)` int constructor | Still works, but prefer `Color.fromARGB` or theme colors | — |

```dart
// BAD
final faded = Colors.black.withOpacity(0.5);

// GOOD
final faded = Colors.black.withValues(alpha: 0.5);
```

Migration: `dart fix --apply` handles most cases automatically.

### Widgets & Components

| Deprecated | Replacement | Since |
|-----------|-------------|-------|
| `FlatButton` | `TextButton` | 2.0 (removed) |
| `RaisedButton` | `ElevatedButton` | 2.0 (removed) |
| `OutlineButton` | `OutlinedButton` | 2.0 (removed) |
| `activeColor` (Switch, Checkbox, Radio) | Component themes or `ColorScheme.secondary` | 3.4 |
| `toggleableActiveColor` (ThemeData) | `ColorScheme.secondary` | 3.4 (removed) |
| `containsSemantics` (tests) | `isSemantics` (partial) / `matchesSemantics` (exact) | 3.41 |
| `findChildIndexCallback` (ListView, SliverList) | `findItemIndexCallback` | 3.41 |
| `FontWeight.index` | `FontWeight.value` | 3.41 |

### ThemeData removed properties

These are fully removed — code using them will not compile:

| Removed | Replacement |
|---------|-------------|
| `errorColor` | `colorScheme.error` |
| `backgroundColor` | `colorScheme.surface` |
| `bottomAppBarColor` | `BottomAppBarTheme.color` |
| `selectedRowColor` | Remove (no longer used) |
| `accentColor` | `colorScheme.secondary` |
| `accentColorBrightness` | Remove |
| `buttonColor` | `colorScheme.primary` |

### TextTheme old names (fully removed)

| Removed | Replacement |
|---------|-------------|
| `headline1`–`headline6` | `displayLarge`, `displayMedium`, `displaySmall`, `headlineMedium`, `headlineSmall`, `titleLarge` |
| `subtitle1`, `subtitle2` | `titleMedium`, `titleSmall` |
| `bodyText1`, `bodyText2` | `bodyLarge`, `bodyMedium` |
| `caption` | `bodySmall` |
| `button` | `labelLarge` |
| `overline` | `labelSmall` |

---

## Material 3

Material 3 is the default since Flutter 3.16. Do not set `useMaterial3: false` unless explicitly required.

### ColorScheme.fromSeed

```dart
// Standard M3 theme
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00615F)),
  useMaterial3: true, // default, can omit
);
```

**Warning:** Flutter 3.41 updated `material_color_utilities` (0.11.1 → 0.13.0). Seeded schemes may produce different values for `onPrimaryContainer`, `onSecondaryContainer`, `onTertiaryContainer`, and `onErrorContainer`. If your UI depends on exact generated colors, override the specific tokens after generation.

### Color equality in tests

With wide-gamut color support, color components are now floating-point. Use matchers:

```dart
// BAD — exact int equality may fail
expect(calculatedColor, const Color(0xFFFF00FF));

// GOOD — floating-point tolerance
expect(calculatedColor, isSameColorAs(const Color(0xFFFF00FF)));
```

---

## Variable Fonts

Since Flutter 3.41, `FontWeight` in a `TextStyle` automatically sets the weight axis on variable fonts. No need for separate `FontVariation` entries for weight:

```dart
// Before 3.41 — needed FontVariation
TextStyle(
  fontFamily: 'Inter',
  fontVariations: [FontVariation('wght', 600)],
)

// After 3.41 — FontWeight drives variable font weight automatically
TextStyle(
  fontFamily: 'Inter',
  fontWeight: FontWeight.w600,
)
```

---

## iOS / Apple Platform

### UIScene Lifecycle (default since 3.41)

Flutter 3.41 defaults to `UISceneDelegate` instead of `AppDelegate`-based lifecycle. This enables proper multi-window support on iPadOS (Stage Manager) and correct background/foreground transitions.

**Impact on existing projects:** custom startup logic, deep link handling, push notification wiring, and scene-related state restoration may break if they rely on `AppDelegate`-era assumptions. Review Flutter's UIScene migration guide.

### Swift Package Manager

Flutter is migrating from CocoaPods to Swift Package Manager for plugin distribution. Plugin authors should treat SwiftPM as the standard going forward. For app developers, this improves build stability across Xcode updates.

### iOS 26 / Xcode 26

Apple switched to year-based versioning at WWDC 2025 (skipping iOS 19–25, jumping to iOS 26). Flutter 3.38+ supports iOS 26 and Xcode 26.

---

## Android

### Impeller (default renderer)

Impeller is the default rendering engine on Android (API level 29+, Android 10+). Skia backend is being removed for these devices. Impeller eliminates shader compilation jank and delivers consistent 60/120 FPS.

### 16KB Page Size

Android 15 mandates 16KB memory page sizes for new apps. Flutter 3.38+ ships with NDK r28, ensuring compliance with Google Play requirements for 2026.

### AGP 9 Warning

Do NOT update Android Gradle Plugin to AGP 9 — migration for plugins is not yet supported. The Flutter team is auditing backwards compatibility.

---

## Web

### WebAssembly (Wasm)

WebAssembly is on track to become the default compilation target for Flutter web in 2026, replacing JavaScript. This delivers near-native performance.

---

## Upcoming Changes (2026 Roadmap)

These are announced but may not be finalized:

- **Material & Cupertino decoupling** — Material and Cupertino libraries will become separate packages. May require import changes when it ships (migration tools will be provided).
- **Flutter 4.0** — speculated for mid-to-late 2026 if core roadmap goals are achieved. Would be the first major version bump since 2022.
- **Android 17 ("Cinnamon Bun")** — expected June 2026, Flutter will provide day-zero support.
- **Out-of-tree platform support** — engine extensibility improvements to allow new platforms without forking.

---

## Build & Migration Commands

```bash
# Upgrade Flutter
flutter upgrade

# Check current version
flutter --version

# Auto-fix deprecated APIs
dart fix --apply

# Analyze for deprecation warnings
dart analyze

# Regenerate code after upgrade
dart run build_runner build --delete-conflicting-outputs
```

After every Flutter upgrade: run `dart fix --apply`, then `dart analyze`, then `build_runner build`.

---

## Rules for AI Code Generation

1. **Never generate code with deprecated APIs** listed above
2. **Use `withValues(alpha:)` not `withOpacity()`** — always
3. **Use Material 3 TextTheme names** — `bodyMedium` not `bodyText2`
4. **Use `ColorScheme` tokens** — not `ThemeData.accentColor`, `.errorColor`, etc.
5. **Use `isSameColorAs` matcher** in tests, not exact `Color` equality
6. **Assume Impeller** — don't add Skia-specific workarounds
7. **Don't set `useMaterial3: false`** unless explicitly told to
8. **Don't use AGP 9** for Android builds
9. **Use `FontWeight`** for variable fonts, not `FontVariation('wght', ...)`
10. When unsure if an API is deprecated — check `dart analyze` output