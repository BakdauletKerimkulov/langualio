import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/notifier_mounted.dart';
import '../../word_quiz/domain/word_entry.dart';
import '../data/admin_repository.dart';

part 'admin_word_list_notifier.g.dart';

@immutable
class AdminWordListState {
  const AdminWordListState({
    this.words = const [],
    this.activeFilter,
    this.isLoading = false,
    this.error,
  });

  final List<WordEntry> words;
  final String? activeFilter;
  final bool isLoading;
  final String? error;

  AdminWordListState copyWith({
    List<WordEntry>? words,
    String? Function()? activeFilter,
    bool? isLoading,
    String? error,
  }) => AdminWordListState(
    words: words ?? this.words,
    activeFilter: activeFilter != null ? activeFilter() : this.activeFilter,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminWordListState &&
          words == other.words &&
          activeFilter == other.activeFilter &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(words, activeFilter, isLoading, error);
}

@riverpod
class AdminWordListNotifier extends _$AdminWordListNotifier
    with NotifierMounted {
  @override
  AdminWordListState build() {
    ref.onDispose(setUnmounted);
    _loadWords();
    return const AdminWordListState(isLoading: true);
  }

  Future<void> _loadWords() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final words = await ref
          .read(adminRepositoryProvider)
          .fetchWords(statusFilter: state.activeFilter);
      if (!mounted) return;
      state = state.copyWith(words: words, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка загрузки: $e',
      );
    }
  }

  void setFilter(String? status) {
    state = state.copyWith(activeFilter: () => status);
    _loadWords();
  }

  Future<void> refresh() => _loadWords();

}
