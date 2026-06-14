// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift.dart';

// ignore_for_file: type=lint
class $WordEntriesTableTable extends WordEntriesTable
    with TableInfo<$WordEntriesTableTable, WordEntriesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordEntriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipaMeta = const VerificationMeta('ipa');
  @override
  late final GeneratedColumn<String> ipa = GeneratedColumn<String>(
    'ipa',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningsMeta = const VerificationMeta(
    'meanings',
  );
  @override
  late final GeneratedColumn<String> meanings = GeneratedColumn<String>(
    'meanings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    ipa,
    level,
    meanings,
    topic,
    tags,
    createdAt,
    updatedAt,
    status,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_entries_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordEntriesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('ipa')) {
      context.handle(
        _ipaMeta,
        ipa.isAcceptableOrUnknown(data['ipa']!, _ipaMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('meanings')) {
      context.handle(
        _meaningsMeta,
        meanings.isAcceptableOrUnknown(data['meanings']!, _meaningsMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningsMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordEntriesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordEntriesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      ipa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      meanings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meanings'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
    );
  }

  @override
  $WordEntriesTableTable createAlias(String alias) {
    return $WordEntriesTableTable(attachedDatabase, alias);
  }
}

class WordEntriesTableData extends DataClass
    implements Insertable<WordEntriesTableData> {
  final String id;
  final String word;
  final String? ipa;
  final String level;
  final String meanings;
  final String? topic;
  final String tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;
  final String? createdBy;
  const WordEntriesTableData({
    required this.id,
    required this.word,
    this.ipa,
    required this.level,
    required this.meanings,
    this.topic,
    required this.tags,
    this.createdAt,
    this.updatedAt,
    this.status,
    this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word'] = Variable<String>(word);
    if (!nullToAbsent || ipa != null) {
      map['ipa'] = Variable<String>(ipa);
    }
    map['level'] = Variable<String>(level);
    map['meanings'] = Variable<String>(meanings);
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    return map;
  }

  WordEntriesTableCompanion toCompanion(bool nullToAbsent) {
    return WordEntriesTableCompanion(
      id: Value(id),
      word: Value(word),
      ipa: ipa == null && nullToAbsent ? const Value.absent() : Value(ipa),
      level: Value(level),
      meanings: Value(meanings),
      topic: topic == null && nullToAbsent
          ? const Value.absent()
          : Value(topic),
      tags: Value(tags),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
    );
  }

  factory WordEntriesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordEntriesTableData(
      id: serializer.fromJson<String>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      ipa: serializer.fromJson<String?>(json['ipa']),
      level: serializer.fromJson<String>(json['level']),
      meanings: serializer.fromJson<String>(json['meanings']),
      topic: serializer.fromJson<String?>(json['topic']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<String?>(json['status']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'word': serializer.toJson<String>(word),
      'ipa': serializer.toJson<String?>(ipa),
      'level': serializer.toJson<String>(level),
      'meanings': serializer.toJson<String>(meanings),
      'topic': serializer.toJson<String?>(topic),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<String?>(status),
      'createdBy': serializer.toJson<String?>(createdBy),
    };
  }

  WordEntriesTableData copyWith({
    String? id,
    String? word,
    Value<String?> ipa = const Value.absent(),
    String? level,
    String? meanings,
    Value<String?> topic = const Value.absent(),
    String? tags,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
  }) => WordEntriesTableData(
    id: id ?? this.id,
    word: word ?? this.word,
    ipa: ipa.present ? ipa.value : this.ipa,
    level: level ?? this.level,
    meanings: meanings ?? this.meanings,
    topic: topic.present ? topic.value : this.topic,
    tags: tags ?? this.tags,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status.present ? status.value : this.status,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
  );
  WordEntriesTableData copyWithCompanion(WordEntriesTableCompanion data) {
    return WordEntriesTableData(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      ipa: data.ipa.present ? data.ipa.value : this.ipa,
      level: data.level.present ? data.level.value : this.level,
      meanings: data.meanings.present ? data.meanings.value : this.meanings,
      topic: data.topic.present ? data.topic.value : this.topic,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordEntriesTableData(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('ipa: $ipa, ')
          ..write('level: $level, ')
          ..write('meanings: $meanings, ')
          ..write('topic: $topic, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    ipa,
    level,
    meanings,
    topic,
    tags,
    createdAt,
    updatedAt,
    status,
    createdBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordEntriesTableData &&
          other.id == this.id &&
          other.word == this.word &&
          other.ipa == this.ipa &&
          other.level == this.level &&
          other.meanings == this.meanings &&
          other.topic == this.topic &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.createdBy == this.createdBy);
}

class WordEntriesTableCompanion extends UpdateCompanion<WordEntriesTableData> {
  final Value<String> id;
  final Value<String> word;
  final Value<String?> ipa;
  final Value<String> level;
  final Value<String> meanings;
  final Value<String?> topic;
  final Value<String> tags;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<String?> status;
  final Value<String?> createdBy;
  final Value<int> rowid;
  const WordEntriesTableCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.ipa = const Value.absent(),
    this.level = const Value.absent(),
    this.meanings = const Value.absent(),
    this.topic = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordEntriesTableCompanion.insert({
    required String id,
    required String word,
    this.ipa = const Value.absent(),
    required String level,
    required String meanings,
    this.topic = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       word = Value(word),
       level = Value(level),
       meanings = Value(meanings);
  static Insertable<WordEntriesTableData> custom({
    Expression<String>? id,
    Expression<String>? word,
    Expression<String>? ipa,
    Expression<String>? level,
    Expression<String>? meanings,
    Expression<String>? topic,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (ipa != null) 'ipa': ipa,
      if (level != null) 'level': level,
      if (meanings != null) 'meanings': meanings,
      if (topic != null) 'topic': topic,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordEntriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? word,
    Value<String?>? ipa,
    Value<String>? level,
    Value<String>? meanings,
    Value<String?>? topic,
    Value<String>? tags,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<String?>? status,
    Value<String?>? createdBy,
    Value<int>? rowid,
  }) {
    return WordEntriesTableCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      ipa: ipa ?? this.ipa,
      level: level ?? this.level,
      meanings: meanings ?? this.meanings,
      topic: topic ?? this.topic,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (ipa.present) {
      map['ipa'] = Variable<String>(ipa.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (meanings.present) {
      map['meanings'] = Variable<String>(meanings.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordEntriesTableCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('ipa: $ipa, ')
          ..write('level: $level, ')
          ..write('meanings: $meanings, ')
          ..write('topic: $topic, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WordEntriesTableTable wordEntriesTable = $WordEntriesTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [wordEntriesTable];
}

typedef $$WordEntriesTableTableCreateCompanionBuilder =
    WordEntriesTableCompanion Function({
      required String id,
      required String word,
      Value<String?> ipa,
      required String level,
      required String meanings,
      Value<String?> topic,
      Value<String> tags,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String?> status,
      Value<String?> createdBy,
      Value<int> rowid,
    });
typedef $$WordEntriesTableTableUpdateCompanionBuilder =
    WordEntriesTableCompanion Function({
      Value<String> id,
      Value<String> word,
      Value<String?> ipa,
      Value<String> level,
      Value<String> meanings,
      Value<String?> topic,
      Value<String> tags,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<String?> status,
      Value<String?> createdBy,
      Value<int> rowid,
    });

class $$WordEntriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $WordEntriesTableTable> {
  $$WordEntriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meanings => $composableBuilder(
    column: $table.meanings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordEntriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WordEntriesTableTable> {
  $$WordEntriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meanings => $composableBuilder(
    column: $table.meanings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordEntriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordEntriesTableTable> {
  $$WordEntriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get ipa =>
      $composableBuilder(column: $table.ipa, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get meanings =>
      $composableBuilder(column: $table.meanings, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);
}

class $$WordEntriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordEntriesTableTable,
          WordEntriesTableData,
          $$WordEntriesTableTableFilterComposer,
          $$WordEntriesTableTableOrderingComposer,
          $$WordEntriesTableTableAnnotationComposer,
          $$WordEntriesTableTableCreateCompanionBuilder,
          $$WordEntriesTableTableUpdateCompanionBuilder,
          (
            WordEntriesTableData,
            BaseReferences<
              _$AppDatabase,
              $WordEntriesTableTable,
              WordEntriesTableData
            >,
          ),
          WordEntriesTableData,
          PrefetchHooks Function()
        > {
  $$WordEntriesTableTableTableManager(
    _$AppDatabase db,
    $WordEntriesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordEntriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordEntriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordEntriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String?> ipa = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> meanings = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordEntriesTableCompanion(
                id: id,
                word: word,
                ipa: ipa,
                level: level,
                meanings: meanings,
                topic: topic,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String word,
                Value<String?> ipa = const Value.absent(),
                required String level,
                required String meanings,
                Value<String?> topic = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordEntriesTableCompanion.insert(
                id: id,
                word: word,
                ipa: ipa,
                level: level,
                meanings: meanings,
                topic: topic,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordEntriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordEntriesTableTable,
      WordEntriesTableData,
      $$WordEntriesTableTableFilterComposer,
      $$WordEntriesTableTableOrderingComposer,
      $$WordEntriesTableTableAnnotationComposer,
      $$WordEntriesTableTableCreateCompanionBuilder,
      $$WordEntriesTableTableUpdateCompanionBuilder,
      (
        WordEntriesTableData,
        BaseReferences<
          _$AppDatabase,
          $WordEntriesTableTable,
          WordEntriesTableData
        >,
      ),
      WordEntriesTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WordEntriesTableTableTableManager get wordEntriesTable =>
      $$WordEntriesTableTableTableManager(_db, _db.wordEntriesTable);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'5272999ed4821a8f4137b2c9bb5c7ad0e11321f6';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
