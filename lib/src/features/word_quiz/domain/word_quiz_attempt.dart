import 'package:flutter/foundation.dart';

import 'quiz_session.dart';

@immutable
class WordQuizAttempt {
  const WordQuizAttempt({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.selectedOption,
    required this.isCorrect,
    required this.languageDirection,
    required this.answeredAt,
  });

  final String id;
  final String userId;
  final String wordId;
  final String selectedOption;
  final bool isCorrect;
  final LanguageDirection languageDirection;
  final DateTime answeredAt;

  factory WordQuizAttempt.fromJson(Map<String, dynamic> json) {
    return WordQuizAttempt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordId: json['word_id'] as String,
      selectedOption: json['selected_option'] as String,
      isCorrect: json['is_correct'] as bool,
      languageDirection: LanguageDirection.fromString(
        json['language_direction'] as String,
      ),
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word_id': wordId,
      'selected_option': selectedOption,
      'is_correct': isCorrect,
      'language_direction': languageDirection.value,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WordQuizAttempt && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
