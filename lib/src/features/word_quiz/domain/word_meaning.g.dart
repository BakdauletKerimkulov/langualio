// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_meaning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WordMeaning _$WordMeaningFromJson(Map<String, dynamic> json) => _WordMeaning(
  partOfSpeech: $enumDecode(_$PartOfSpeechEnumMap, json['part_of_speech']),
  translation: json['translation'] as String,
  alternativeTranslations:
      (json['alternative_translations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  definitionEn: json['definition_en'] as String?,
  definitionRu: json['definition_ru'] as String?,
  exampleEn: json['example_en'] as String,
  exampleRu: json['example_ru'] as String,
);

Map<String, dynamic> _$WordMeaningToJson(_WordMeaning instance) =>
    <String, dynamic>{
      'part_of_speech': _$PartOfSpeechEnumMap[instance.partOfSpeech]!,
      'translation': instance.translation,
      'alternative_translations': instance.alternativeTranslations,
      'definition_en': instance.definitionEn,
      'definition_ru': instance.definitionRu,
      'example_en': instance.exampleEn,
      'example_ru': instance.exampleRu,
    };

const _$PartOfSpeechEnumMap = {
  PartOfSpeech.noun: 'noun',
  PartOfSpeech.verb: 'verb',
  PartOfSpeech.adjective: 'adjective',
  PartOfSpeech.adverb: 'adverb',
  PartOfSpeech.pronoun: 'pronoun',
  PartOfSpeech.preposition: 'preposition',
  PartOfSpeech.conjunction: 'conjunction',
  PartOfSpeech.interjection: 'interjection',
  PartOfSpeech.phrase: 'phrase',
};
