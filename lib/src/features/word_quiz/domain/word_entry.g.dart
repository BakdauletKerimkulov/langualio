// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WordEntry _$WordEntryFromJson(Map<String, dynamic> json) => _WordEntry(
  id: json['id'] as String,
  word: json['word'] as String,
  ipa: json['ipa'] as String?,
  level: $enumDecode(_$DifficultyLevelEnumMap, json['level']),
  meanings: (json['meanings'] as List<dynamic>)
      .map((e) => WordMeaning.fromJson(e as Map<String, dynamic>))
      .toList(),
  topic: json['topic'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  status: json['status'] as String?,
  createdBy: json['created_by'] as String?,
);

Map<String, dynamic> _$WordEntryToJson(_WordEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'word': instance.word,
      'ipa': instance.ipa,
      'level': _$DifficultyLevelEnumMap[instance.level]!,
      'meanings': instance.meanings.map((e) => e.toJson()).toList(),
      'topic': instance.topic,
      'tags': instance.tags,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'status': instance.status,
      'created_by': instance.createdBy,
    };

const _$DifficultyLevelEnumMap = {
  DifficultyLevel.a1: 'a1',
  DifficultyLevel.a2: 'a2',
  DifficultyLevel.b1: 'b1',
  DifficultyLevel.b2: 'b2',
  DifficultyLevel.c1: 'c1',
  DifficultyLevel.c2: 'c2',
};
