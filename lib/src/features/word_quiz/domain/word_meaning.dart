import 'package:freezed_annotation/freezed_annotation.dart';

import 'part_of_speech.dart';

part 'word_meaning.freezed.dart';
part 'word_meaning.g.dart';

@freezed
abstract class WordMeaning with _$WordMeaning {
  const factory WordMeaning({
    required PartOfSpeech partOfSpeech,
    required String translation,
    @Default(<String>[]) List<String> alternativeTranslations,
    String? definitionEn,
    String? definitionRu,
    required String exampleEn,
    required String exampleRu,
  }) = _WordMeaning;

  factory WordMeaning.fromJson(Map<String, dynamic> json) =>
      _$WordMeaningFromJson(json);
}
