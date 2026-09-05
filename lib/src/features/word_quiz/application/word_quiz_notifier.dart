import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/local_storage/storage_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/notifier_mounted.dart';
import '../data/quiz_attempt_repository.dart';
import '../domain/quiz_day_util.dart';
import '../domain/quiz_session.dart';
import '../domain/word_entry.dart';
import '../domain/word_quiz_attempt.dart';
import 'word_pool_provider.dart';

part 'word_quiz_notifier.g.dart';

@riverpod
class WordQuizNotifier extends _$WordQuizNotifier with NotifierMounted {
  static const _directionKey = 'word_quiz_direction';
  static const _answeredIdsKey = 'word_quiz_answered_ids';

  QuizAttemptRepository get _attemptRepo =>
      ref.read(quizAttemptRepositoryProvider);

  @override
  Future<QuizSession> build() async {
    ref.onDispose(setUnmounted);
    final storage = ref.read(localStorageProvider);
    final directionStr = storage.getString(_directionKey);
    final direction = directionStr != null
        ? LanguageDirection.fromString(directionStr)
        : LanguageDirection.enToRu;

    final quizDay = getQuizDay();

    // Load words from local pool (asset + user Drift words)
    List<WordEntry> words;
    try {
      words = await ref.read(wordPoolProvider.future);
    } catch (e) {
      log('Failed to load word pool: $e', name: 'WordQuizNotifier');
      words = [];
    }

    // Load today's attempts for current direction
    List<WordQuizAttempt> attempts;
    try {
      attempts = await _attemptRepo.fetchTodayAttempts(direction);
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
  /// Sets `AsyncError` state on network failure so the UI can show an error.
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

    try {
      // Save attempt to Supabase
      await _attemptRepo.saveAttempt(attempt);

      // Update learning progress if correct
      if (isCorrect) {
        await _attemptRepo.updateLearningProgress(
          wordId: wordId,
          correctDate: quizDay,
        );
      }
    } catch (e, st) {
      log('Failed to save attempt: $e', name: 'WordQuizNotifier');
      if (mounted) state = AsyncError(e, st);
      return;
    }

    // Update session state
    final newAnsweredIds = {...session.answeredWordIds, wordId};
    final newAttempts = [...session.attempts, attempt];

    _saveAnsweredIds(newAnsweredIds);

    if (mounted) {
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
}
