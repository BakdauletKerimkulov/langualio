import 'package:flutter/foundation.dart';

@immutable
class DailyWord {
  const DailyWord({
    required this.id,
    required this.wordEn,
    required this.wordRu,
  });

  final String id;
  final String wordEn;
  final String wordRu;

  factory DailyWord.fromJson(Map<String, dynamic> json) {
    return DailyWord(
      id: json['id'] as String,
      wordEn: json['word_en'] as String,
      wordRu: json['word_ru'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWord &&
          id == other.id &&
          wordEn == other.wordEn &&
          wordRu == other.wordRu;

  @override
  int get hashCode => Object.hash(id, wordEn, wordRu);

  @override
  String toString() => 'DailyWord(id: $id, wordEn: $wordEn, wordRu: $wordRu)';
}
