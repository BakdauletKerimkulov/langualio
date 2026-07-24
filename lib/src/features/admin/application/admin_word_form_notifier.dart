import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/notifier_mounted.dart';
import '../../word_quiz/domain/word_entry.dart';
import '../data/admin_repository.dart';

part 'admin_word_form_notifier.g.dart';

@immutable
class AdminWordFormState {
  const AdminWordFormState({
    this.generatedData,
    this.isGenerating = false,
    this.isSaving = false,
    this.error,
    this.duplicateWarning = false,
  });

  final WordEntry? generatedData;
  final bool isGenerating;
  final bool isSaving;
  final String? error;
  final bool duplicateWarning;

  AdminWordFormState copyWith({
    WordEntry? generatedData,
    bool? isGenerating,
    bool? isSaving,
    String? error,
    bool? duplicateWarning,
  }) => AdminWordFormState(
    generatedData: generatedData ?? this.generatedData,
    isGenerating: isGenerating ?? this.isGenerating,
    isSaving: isSaving ?? this.isSaving,
    error: error,
    duplicateWarning: duplicateWarning ?? this.duplicateWarning,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminWordFormState &&
          generatedData == other.generatedData &&
          isGenerating == other.isGenerating &&
          isSaving == other.isSaving &&
          error == other.error &&
          duplicateWarning == other.duplicateWarning;

  @override
  int get hashCode => Object.hash(
    generatedData,
    isGenerating,
    isSaving,
    error,
    duplicateWarning,
  );
}

@riverpod
class AdminWordFormNotifier extends _$AdminWordFormNotifier
    with NotifierMounted {
  @override
  AdminWordFormState build() {
    ref.onDispose(setUnmounted);
    return const AdminWordFormState();
  }

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  /// Calls the Edge Function to generate word data from AI.
  Future<void> generate(String word) async {
    if (word.trim().isEmpty) return;

    state = state.copyWith(isGenerating: true, error: null, duplicateWarning: false);

    try {
      // Check for duplicate first
      final isDuplicate = await _repo.checkDuplicateWord(word);
      if (!mounted) return;

      if (isDuplicate) {
        state = state.copyWith(isGenerating: false, duplicateWarning: true);
      }

      final data = await _repo.generateWordEntry(word);
      if (!mounted) return;

      state = state.copyWith(
        generatedData: data,
        isGenerating: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        error: 'Ошибка генерации: $e',
      );
    }
  }

  /// Saves the word to the database with the given status.
  Future<bool> save({
    required WordEntry entry,
    required String status,
  }) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      await _repo.createWord(entry, status: status);
      if (!mounted) return false;
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: 'Ошибка сохранения: $e',
      );
      return false;
    }
  }

  /// Updates an existing word in the database.
  Future<bool> update({
    required String wordId,
    required WordEntry entry,
    required String status,
  }) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      await _repo.updateWord(wordId, entry, status: status);
      if (!mounted) return false;
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: 'Ошибка обновления: $e',
      );
      return false;
    }
  }

  /// Clears the duplicate warning.
  void clearDuplicateWarning() {
    state = state.copyWith(duplicateWarning: false);
  }

}
