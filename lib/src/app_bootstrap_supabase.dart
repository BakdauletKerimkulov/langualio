import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langualio/src/app_bootstrap.dart';
import 'package:langualio/src/core/exceptions/async_error_logger.dart';
import 'package:langualio/src/core/local_storage/drift.dart';
import 'package:langualio/src/core/local_storage/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension AppBootstrapSupabase on AppBootstrap {
  /// Creates the top-level [ProviderContainer] by overriding providers with fake
  /// repositories only. This is useful for testing purposes and for running the
  /// app with a "fake" backend.
  ///
  /// Note: all repositories needed by the app can be accessed via providers.
  /// Some of these providers throw an [UnimplementedError] by default.
  ///
  /// Example:
  /// ```dart
  /// @Riverpod(keepAlive: true)
  /// LocalCartRepository localCartRepository(LocalCartRepositoryRef ref) {
  ///   throw UnimplementedError();
  /// }
  /// ```
  ///
  /// As a result, this method does two things:
  /// - create and configure the repositories as desired
  /// - override the default implementations with a list of "overrides"
  Future<ProviderContainer> createSupabaseContainerProvider() async {
    final drift = AppDatabase();
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(drift),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      observers: [AsyncErrorLogger()],
    );
  }
}
