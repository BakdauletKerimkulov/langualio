import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/notifier_mounted.dart';
import '../../auth/data/auth_repository.dart';
import '../data/local/asset_word_repository.dart';
import '../data/local/user_word_repository.dart';
import '../data/word_generation_service.dart';
import '../domain/word_entry.dart';
import 'word_pool_provider.dart';

part 'add_word_notifier.g.dart';

/// State for the add-word flow.
@immutable
class AddWordState {
  const AddWordState({
    this.preview,
    this.isGenerating = false,
    this.isSaving = false,
    this.error,
    this.saved = false,
  });

  final WordEntry? preview;
  final bool isGenerating;
  final bool isSaving;
  final String? error;
  final bool saved;

  AddWordState copyWith({
    WordEntry? preview,
    bool? isGenerating,
    bool? isSaving,
    String? error,
    bool? saved,
    bool clearPreview = false,
    bool clearError = false,
  }) =>
      AddWordState(
        preview: clearPreview ? null : (preview ?? this.preview),
        isGenerating: isGenerating ?? this.isGenerating,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
        saved: saved ?? this.saved,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddWordState &&
          preview == other.preview &&
          isGenerating == other.isGenerating &&
          isSaving == other.isSaving &&
          error == other.error &&
          saved == other.saved;

  @override
  int get hashCode =>
      Object.hash(preview, isGenerating, isSaving, error, saved);
}

@riverpod
class AddWordNotifier extends _$AddWordNotifier with NotifierMounted {
  @override
  AddWordState build() {
    ref.onDispose(setUnmounted);
    return const AddWordState();
  }

  /// Generates a word entry preview via the Edge Function.
  /// Checks for duplicates in both asset pool and user Drift words.
  Future<void> generate(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(
      isGenerating: true,
      clearError: true,
      clearPreview: true,
      saved: false,
    );

    try {
      // Check for duplicates in asset words
      final assetWords = await ref.read(assetWordsProvider.future);
      final assetDuplicate = assetWords.any(
        (w) => w.word.toLowerCase() == trimmed.toLowerCase(),
      );
      if (assetDuplicate) {
        if (mounted) {
          state = state.copyWith(
            isGenerating: false,
            error: 'Это слово уже есть в вашей коллекции',
          );
        }
        return;
      }

      // Check for duplicates in user Drift words
      final userRepo = ref.read(userWordRepositoryProvider);
      final userDuplicate = await userRepo.existsByWord(trimmed);
      if (userDuplicate) {
        if (mounted) {
          state = state.copyWith(
            isGenerating: false,
            error: 'Это слово уже есть в вашей коллекции',
          );
        }
        return;
      }

      // Generate via Edge Function
      final service = ref.read(wordGenerationServiceProvider);
      final entry = await service.generateWordEntry(trimmed);

      if (mounted) {
        state = state.copyWith(isGenerating: false, preview: entry);
      }
    } on WordGenerationException catch (e) {
      log('Word generation failed: $e', name: 'AddWordNotifier');
      if (mounted) {
        final message = switch (e.statusCode) {
          401 => 'Войдите в аккаунт заново',
          429 => 'Дневной лимит исчерпан. Попробуйте завтра.',
          _ => 'Ошибка генерации. Попробуйте ещё раз.',
        };
        state = state.copyWith(isGenerating: false, error: message);
      }
    } catch (e) {
      log('Word generation failed: $e', name: 'AddWordNotifier');
      if (mounted) {
        state = state.copyWith(
          isGenerating: false,
          error: 'Ошибка генерации. Попробуйте ещё раз.',
        );
      }
    }
  }

  /// Saves the previewed word entry to the local Drift database.
  /// Returns `true` on success.
  Future<bool> save() async {
    final preview = state.preview;
    if (preview == null) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final userRepo = ref.read(userWordRepositoryProvider);
      await userRepo.insert(preview, userId: _currentUserId);

      // Invalidate word pool so the quiz picks up the new word
      ref.invalidate(wordPoolProvider);

      if (mounted) {
        state = state.copyWith(isSaving: false, saved: true);
      }
      log('Word saved: ${preview.word}', name: 'AddWordNotifier');
      return true;
    } catch (e) {
      log('Word save failed: $e', name: 'AddWordNotifier');
      if (mounted) {
        state = state.copyWith(
          isSaving: false,
          error: 'Не удалось сохранить слово',
        );
      }
      return false;
    }
  }

  String get _currentUserId {
    return ref.read(authRepositoryProvider).currentUser?.id ?? '';
  }
}
