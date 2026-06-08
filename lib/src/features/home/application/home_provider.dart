import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/home_repository.dart';
import '../domain/user_progress.dart';

part 'home_provider.g.dart';

@riverpod
class UserProgressNotifier extends _$UserProgressNotifier {
  @override
  Future<UserProgress> build() async {
    final repo = ref.read(homeRepositoryProvider);
    return repo.fetchUserProgress();
  }

  /// Refresh progress from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(homeRepositoryProvider);
      final progress = await repo.fetchUserProgress();
      if (_mounted) state = AsyncData(progress);
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
