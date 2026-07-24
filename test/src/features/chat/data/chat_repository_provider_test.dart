import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/core/local_storage/storage_provider.dart';
import 'package:langualio/src/core/supabase/supabase_client.dart';
import 'package:langualio/src/features/chat/data/chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('chatRepositoryProvider resolves without UnimplementedError', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        // Override the same provider that app_bootstrap overrides
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(
          _FakeSupabaseClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // This should NOT throw UnimplementedError
    expect(
      () => container.read(chatRepositoryProvider),
      returnsNormally,
    );
  });
}

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
