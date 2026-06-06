import 'package:flutter/foundation.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';

import 'word_quiz_attempt.dart';

enum LanguageDirection {
  enToRu('en_to_ru'),
  ruToEn('ru_to_en');

  const LanguageDirection(this.value);
  final String value;

  static LanguageDirection fromString(String value) {
    return LanguageDirection.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LanguageDirection.enToRu,
    );
  }
}

@immutable
class QuizSession {
  const QuizSession({
    this.todayWords = const [],
    this.answeredWordIds = const {},
    this.attempts = const [],
    required this.quizDay,
    this.languageDirection = LanguageDirection.enToRu,
    this.selectedMeaningIndexes = const {},
  });

  final List<WordEntry> todayWords;
  final Set<String> answeredWordIds;
  final List<WordQuizAttempt> attempts;
  final DateTime quizDay;
  final LanguageDirection languageDirection;

  /// Maps wordId → meaning index (randomly chosen at session creation).
  /// Not part of equality — it's randomized per session.
  final Map<String, int> selectedMeaningIndexes;

  int get totalWords => todayWords.length;
  int get answeredCount => answeredWordIds.length;
  bool get isFinished => todayWords.isNotEmpty && answeredCount >= totalWords;

  /// Returns the next unanswered word, or null if all are answered.
  WordEntry? get currentWord {
    for (final word in todayWords) {
      if (!answeredWordIds.contains(word.id)) return word;
    }
    return null;
  }

  int get correctCount => attempts.where((a) => a.isCorrect).length;

  List<WordQuizAttempt> get mistakes =>
      attempts.where((a) => !a.isCorrect).toList();

  QuizSession copyWith({
    List<WordEntry>? todayWords,
    Set<String>? answeredWordIds,
    List<WordQuizAttempt>? attempts,
    DateTime? quizDay,
    LanguageDirection? languageDirection,
    Map<String, int>? selectedMeaningIndexes,
  }) {
    return QuizSession(
      todayWords: todayWords ?? this.todayWords,
      answeredWordIds: answeredWordIds ?? this.answeredWordIds,
      attempts: attempts ?? this.attempts,
      quizDay: quizDay ?? this.quizDay,
      languageDirection: languageDirection ?? this.languageDirection,
      selectedMeaningIndexes:
          selectedMeaningIndexes ?? this.selectedMeaningIndexes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizSession &&
          quizDay == other.quizDay &&
          languageDirection == other.languageDirection &&
          answeredCount == other.answeredCount &&
          totalWords == other.totalWords;

  @override
  int get hashCode =>
      Object.hash(quizDay, languageDirection, answeredCount, totalWords);
}
