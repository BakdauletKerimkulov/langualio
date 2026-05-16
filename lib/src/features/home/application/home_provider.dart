import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/user_progress.dart';

part 'home_provider.g.dart';

@riverpod
class UserProgressNotifier extends _$UserProgressNotifier {
  @override
  UserProgress build() => UserProgress.mock;

  void update(UserProgress progress) {
    state = progress;
  }
}
