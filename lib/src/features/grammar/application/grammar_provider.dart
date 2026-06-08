import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/grammar_repository.dart';
import '../domain/grammar_item.dart';

part 'grammar_provider.g.dart';

@riverpod
class GrammarItemsNotifier extends _$GrammarItemsNotifier {
  @override
  Future<List<GrammarItem>> build() async {
    final repo = ref.read(grammarRepositoryProvider);
    return repo.fetchGrammarItems();
  }

  /// Refresh grammar items from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(grammarRepositoryProvider);
      final items = await repo.fetchGrammarItems();
      if (_mounted) state = AsyncData(items);
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
