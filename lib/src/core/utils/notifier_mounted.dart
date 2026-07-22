/// Mixin for auto-dispose Notifiers to guard against setting state after disposal.
///
/// Wire it up in `build()` with `ref.onDispose(setUnmounted)`:
/// ```dart
/// @override
/// FutureOr<void> build() {
///   ref.onDispose(setUnmounted);
/// }
/// ```
mixin NotifierMounted {
  bool _mounted = true;
  void setUnmounted() => _mounted = false;
  bool get mounted => _mounted;
}
