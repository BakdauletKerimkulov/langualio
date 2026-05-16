import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage.dart';

part 'storage_provider.g.dart';

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

@Riverpod(keepAlive: true)
LocalStorage localStorage(Ref ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
}
