import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/notifier_mounted.dart';
import '../data/home_repository.dart';
import '../domain/user_progress.dart';

part 'home_provider.g.dart';

@riverpod
class UserProgressNotifier extends _$UserProgressNotifier with NotifierMounted {
  @override
  Future<UserProgress> build() async {
    ref.onDispose(setUnmounted);
    final repo = ref.read(homeRepositoryProvider);
    return repo.fetchUserProgress();
  }

  /// Refresh progress from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(homeRepositoryProvider);
      final progress = await repo.fetchUserProgress();
      if (mounted) state = AsyncData(progress);
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }
}
