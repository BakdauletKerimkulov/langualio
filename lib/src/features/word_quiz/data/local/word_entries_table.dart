import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:langualio/src/core/local_storage/drift.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

class WordEntriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get word => text()();
  TextColumn get ipa => text().nullable()();
  TextColumn get level => text()();
  TextColumn get meanings => text()();
  TextColumn get topic => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get createdBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

extension WordEntriesTableDataX on WordEntriesTableData {
  WordEntry toModel() {
    final meaningsList = (jsonDecode(meanings) as List)
        .map((m) => WordMeaning.fromJson(m as Map<String, dynamic>))
        .toList();

    return WordEntry(
      id: id,
      word: word,
      ipa: ipa,
      level: DifficultyLevel.values.byName(level),
      meanings: meaningsList,
      topic: topic,
      tags: List<String>.from(jsonDecode(tags)),
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status,
      createdBy: createdBy,
    );
  }
}

extension WordEntryX on WordEntry {
  WordEntriesTableCompanion toCompanion() => WordEntriesTableCompanion.insert(
    id: id,
    word: word,
    ipa: Value.absentIfNull(ipa),
    level: level.name,
    meanings: jsonEncode(meanings.map((m) => m.toJson()).toList()),
    topic: Value.absentIfNull(topic),
    tags: Value(jsonEncode(tags)),
    createdAt: Value.absentIfNull(createdAt),
    updatedAt: Value.absentIfNull(updatedAt),
    status: Value.absentIfNull(status),
    createdBy: Value.absentIfNull(createdBy),
  );
}
