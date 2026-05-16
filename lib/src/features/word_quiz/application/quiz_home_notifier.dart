import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/quiz_session.dart';
import '../domain/word_quiz_attempt.dart';
import 'word_quiz_notifier.dart';

part 'quiz_home_notifier.g.dart';

@immutable
class QuizHomeState {
  const QuizHomeState({
    this.completedCount = 0,
    this.totalWords = 0,
    this.isFinished = false,
    this.correctCount = 0,
    this.mistakes = const [],
    this.languageDirection = LanguageDirection.enToRu,
    this.hasWords = false,
  });

  final int completedCount;
  final int totalWords;
  final bool isFinished;
  final int correctCount;
  final List<WordQuizAttempt> mistakes;
  final LanguageDirection languageDirection;
  final bool hasWords;

  double get scorePercent =>
      totalWords > 0 ? correctCount / totalWords : 0.0;

  QuizHomeState copyWith({
    int? completedCount,
    int? totalWords,
    bool? isFinished,
    int? correctCount,
    List<WordQuizAttempt>? mistakes,
    LanguageDirection? languageDirection,
    bool? hasWords,
  }) {
    return QuizHomeState(
      completedCount: completedCount ?? this.completedCount,
      totalWords: totalWords ?? this.totalWords,
      isFinished: isFinished ?? this.isFinished,
      correctCount: correctCount ?? this.correctCount,
      mistakes: mistakes ?? this.mistakes,
      languageDirection: languageDirection ?? this.languageDirection,
      hasWords: hasWords ?? this.hasWords,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizHomeState &&
          completedCount == other.completedCount &&
          totalWords == other.totalWords &&
          isFinished == other.isFinished &&
          correctCount == other.correctCount &&
          languageDirection == other.languageDirection &&
          hasWords == other.hasWords;

  @override
  int get hashCode => Object.hash(
      completedCount, totalWords, isFinished, correctCount,
      languageDirection, hasWords);
}

@riverpod
class QuizHomeNotifier extends _$QuizHomeNotifier {
  @override
  QuizHomeState build() {
    final quizAsync = ref.watch(wordQuizNotifierProvider);

    return quizAsync.when(
      data: (session) => QuizHomeState(
        completedCount: session.answeredCount,
        totalWords: session.totalWords,
        isFinished: session.isFinished,
        correctCount: session.correctCount,
        mistakes: session.mistakes,
        languageDirection: session.languageDirection,
        hasWords: session.todayWords.isNotEmpty,
      ),
      loading: () => const QuizHomeState(),
      error: (_, __) => const QuizHomeState(),
    );
  }

  /// Switches language direction via the quiz notifier.
  Future<void> switchDirection(LanguageDirection direction) async {
    await ref
        .read(wordQuizNotifierProvider.notifier)
        .switchDirection(direction);
  }
}
