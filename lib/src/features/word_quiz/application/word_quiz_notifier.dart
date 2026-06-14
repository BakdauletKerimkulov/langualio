import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/local_storage/storage_provider.dart';
import '../../../core/utils/logger.dart';
import '../data/local/asset_word_repository.dart';
import '../data/remote/word_quiz_repository.dart';
import '../domain/quiz_day_util.dart';
import '../domain/quiz_session.dart';
import '../domain/word_entry.dart';
import '../domain/word_quiz_attempt.dart';

part 'word_quiz_notifier.g.dart';

@riverpod
class WordQuizNotifier extends _$WordQuizNotifier {
  static const _directionKey = 'word_quiz_direction';
  static const _answeredIdsKey = 'word_quiz_answered_ids';

  WordQuizRepository get _repo => ref.read(wordQuizRepositoryProvider);

  @override
  Future<QuizSession> build() async {
    final storage = ref.read(localStorageProvider);
    final directionStr = storage.getString(_directionKey);
    final direction = directionStr != null
        ? LanguageDirection.fromString(directionStr)
        : LanguageDirection.enToRu;

    final quizDay = getQuizDay();

    // Load asset words as base pool
    List<WordEntry> assetWords;
    try {
      assetWords = await ref.read(assetWordsProvider.future);
    } catch (e) {
      log('Failed to load asset words: $e', name: 'WordQuizNotifier');
      assetWords = [];
    }

    // Try server words, merge with asset pool (server overrides by id)
    List<WordEntry> words;
    try {
      final serverWords = await _repo.fetchTodaysWords();
      final tagged = serverWords
          .map((w) => w.copyWith(source: WordSource.server))
          .toList();
      final serverIds = tagged.map((w) => w.id).toSet();
      final assetOnly = assetWords.where((w) => !serverIds.contains(w.id));
      words = [...tagged, ...assetOnly];
    } catch (e) {
      log(
        'Failed to fetch server words, using asset words: $e',
        name: 'WordQuizNotifier',
      );
      // Fallback: try cache, then asset-only
      final cached = _repo.getCachedTodaysWords();
      if (cached != null && cached.isNotEmpty) {
        final tagged = cached
            .map((w) => w.copyWith(source: WordSource.server))
            .toList();
        final cachedIds = tagged.map((w) => w.id).toSet();
        final assetOnly = assetWords.where((w) => !cachedIds.contains(w.id));
        words = [...tagged, ...assetOnly];
      } else {
        words = assetWords;
      }
    }

    // Load today's attempts for current direction
    List<WordQuizAttempt> attempts;
    try {
      attempts = await _repo.fetchTodayAttempts(direction);
    } catch (e) {
      log('Failed to fetch today attempts: $e', name: 'WordQuizNotifier');
      attempts = [];
    }

    final answeredWordIds = attempts.map((a) => a.wordId).toSet();

    // Persist answered IDs to local cache
    _saveAnsweredIds(answeredWordIds);

    // Assign a random meaning index per word for this session
    final random = Random();
    final selectedMeaningIndexes = <String, int>{};
    for (final word in words) {
      selectedMeaningIndexes[word.id] = word.meanings.length > 1
          ? random.nextInt(word.meanings.length)
          : 0;
    }

    log(
      'Quiz loaded: ${words.length} words, ${answeredWordIds.length} answered, direction=${direction.value}',
      name: 'WordQuizNotifier',
    );

    return QuizSession(
      todayWords: words,
      answeredWordIds: answeredWordIds,
      attempts: attempts,
      quizDay: quizDay,
      languageDirection: direction,
      selectedMeaningIndexes: selectedMeaningIndexes,
    );
  }

  /// Generates 4 options for the given word (1 correct + 3 distractors).
  List<String> generateOptions(WordEntry word) {
    final session = state.valueOrNull;
    if (session == null) return [];

    final isEnToRu = session.languageDirection == LanguageDirection.enToRu;

    // Use the selected meaning index for this word (default to 0)
    final meaningIndex = session.selectedMeaningIndexes[word.id] ?? 0;
    final selectedMeaning = word.meanings[meaningIndex];

    // Correct answer
    final correctAnswer = isEnToRu ? selectedMeaning.translation : word.word;

    // Build distractor pool from today's words (excluding current word)
    final pool = session.todayWords
        .where((w) => w.id != word.id)
        .map((w) => isEnToRu ? w.primaryTranslation : w.word)
        .toSet()
        .toList();

    // Shuffle and pick up to 3 distractors
    final random = Random();
    pool.shuffle(random);
    final distractors = pool.take(3).toList();

    // If we don't have enough distractors, the pool is too small
    // This shouldn't happen with 20 words, but handle gracefully
    if (distractors.length < 3) {
      log(
        'Warning: only ${distractors.length} distractors available',
        name: 'WordQuizNotifier',
      );
    }

    final options = [correctAnswer, ...distractors];
    options.shuffle(random);
    return options;
  }

  /// Submits an answer for the given word.
  Future<void> submitAnswer({
    required String wordId,
    required String selectedOption,
    required bool isCorrect,
  }) async {
    final session = state.valueOrNull;
    if (session == null) return;

    final quizDay = session.quizDay;

    // Create attempt
    final attempt = WordQuizAttempt(
      id: '', // Server generates ID
      userId: '', // Server uses auth.uid()
      wordId: wordId,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      languageDirection: session.languageDirection,
      answeredAt: DateTime.now(),
    );

    // Save attempt (queues locally on failure)
    await _repo.saveAttempt(attempt);

    // Update learning progress if correct
    if (isCorrect) {
      await _repo.updateLearningProgress(wordId: wordId, correctDate: quizDay);
    }

    // Update session state
    final newAnsweredIds = {...session.answeredWordIds, wordId};
    final newAttempts = [...session.attempts, attempt];

    _saveAnsweredIds(newAnsweredIds);

    if (_mounted) {
      state = AsyncData(
        session.copyWith(
          answeredWordIds: newAnsweredIds,
          attempts: newAttempts,
        ),
      );
    }

    log(
      'Answer submitted: wordId=$wordId, correct=$isCorrect, progress=${newAnsweredIds.length}/${session.totalWords}',
      name: 'WordQuizNotifier',
    );
  }

  /// Switches the language direction and reloads the session.
  Future<void> switchDirection(LanguageDirection direction) async {
    final storage = ref.read(localStorageProvider);
    await storage.setString(_directionKey, direction.value);

    // Clear local answered IDs cache
    await storage.remove(_answeredIdsKey);

    // Reload the session with new direction
    ref.invalidateSelf();
  }

  void _saveAnsweredIds(Set<String> ids) {
    final storage = ref.read(localStorageProvider);
    storage.setString(_answeredIdsKey, ids.join(','));
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
