import 'package:flutter/foundation.dart';

@immutable
class WordLearningProgress {
  const WordLearningProgress({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.correctCount,
    this.lastCorrectDate,
    this.learnedAt,
    this.datesCorrect = const [],
  });

  final String id;
  final String userId;
  final String wordId;
  final int correctCount;
  final DateTime? lastCorrectDate;
  final DateTime? learnedAt;
  final List<String> datesCorrect;

  bool get isLearned => learnedAt != null;

  factory WordLearningProgress.fromJson(Map<String, dynamic> json) {
    final datesRaw = json['dates_correct'];
    final dates = datesRaw is List
        ? datesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return WordLearningProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordId: json['word_id'] as String,
      correctCount: json['correct_count'] as int? ?? 0,
      lastCorrectDate: json['last_correct_date'] != null
          ? DateTime.parse(json['last_correct_date'] as String)
          : null,
      learnedAt: json['learned_at'] != null
          ? DateTime.parse(json['learned_at'] as String)
          : null,
      datesCorrect: dates,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordLearningProgress && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
