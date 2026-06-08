import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

part 'profile_provider.g.dart';

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  Future<UserProfile> build() async {
    final repo = ref.read(profileRepositoryProvider);
    return repo.fetchUserProfile();
  }

  /// Refresh profile from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.fetchUserProfile();
      if (_mounted) state = AsyncData(profile);
    } catch (e, st) {
      if (_mounted) state = AsyncError(e, st);
    }
  }

  bool get _mounted {
    try {
      state;
      return true;
    } catch (_) {
      return false;
    }
  }
}
