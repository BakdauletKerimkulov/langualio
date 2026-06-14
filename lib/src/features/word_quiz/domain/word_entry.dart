import 'package:freezed_annotation/freezed_annotation.dart';

import 'part_of_speech.dart';
import 'word_meaning.dart';

part 'word_entry.freezed.dart';
part 'word_entry.g.dart';

@freezed
abstract class WordEntry with _$WordEntry {
  const WordEntry._();

  const factory WordEntry({
    required String id,
    required String word,
    String? ipa,
    required DifficultyLevel level,
    required List<WordMeaning> meanings,
    String? topic,
    @Default(<String>[]) List<String> tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? createdBy,
  }) = _WordEntry;

  factory WordEntry.fromJson(Map<String, dynamic> json) =>
      _$WordEntryFromJson(json);

  /// Primary translation from the first meaning.
  String get primaryTranslation => meanings.first.translation;

  /// Primary part of speech from the first meaning.
  PartOfSpeech get primaryPartOfSpeech => meanings.first.partOfSpeech;
}
