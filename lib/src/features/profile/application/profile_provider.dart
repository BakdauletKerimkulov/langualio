import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/notifier_mounted.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

part 'profile_provider.g.dart';

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier with NotifierMounted {
  @override
  Future<UserProfile> build() async {
    ref.onDispose(setUnmounted);
    final repo = ref.read(profileRepositoryProvider);
    return repo.fetchUserProfile();
  }

  /// Refresh profile from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.fetchUserProfile();
      if (mounted) state = AsyncData(profile);
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }
}
