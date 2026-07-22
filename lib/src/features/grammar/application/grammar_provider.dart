import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/notifier_mounted.dart';
import '../data/grammar_repository.dart';
import '../domain/grammar_item.dart';

part 'grammar_provider.g.dart';

@riverpod
class GrammarItemsNotifier extends _$GrammarItemsNotifier
    with NotifierMounted {
  @override
  Future<List<GrammarItem>> build() async {
    ref.onDispose(setUnmounted);
    final repo = ref.read(grammarRepositoryProvider);
    return repo.fetchGrammarItems();
  }

  /// Refresh grammar items from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(grammarRepositoryProvider);
      final items = await repo.fetchGrammarItems();
      if (mounted) state = AsyncData(items);
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }
}
