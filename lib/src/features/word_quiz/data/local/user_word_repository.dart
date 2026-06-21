import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/local_storage/drift.dart';
import '../../domain/word_entry.dart';
import 'word_entries_table.dart';

part 'user_word_repository.g.dart';

class UserWordRepository {
  const UserWordRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Returns all user-added words from the local Drift database.
  Future<List<WordEntry>> fetchAll() async {
    final rows = await _db.select(_db.wordEntriesTable).get();
    return rows.map((row) => row.toModel()).toList();
  }

  /// Inserts a word entry into the local Drift database.
  /// Generates a UUID for the `id` field and sets `createdBy` to the given user ID.
  Future<void> insert(WordEntry entry, {required String userId}) async {
    final withId = entry.copyWith(
      id: _uuid.v4(),
      createdBy: userId,
      createdAt: DateTime.now(),
    );
    await _db.into(_db.wordEntriesTable).insert(withId.toCompanion());
  }

  /// Checks if a word already exists in the local database (case-insensitive).
  Future<bool> existsByWord(String word) async {
    final query = _db.select(_db.wordEntriesTable)
      ..where((t) => t.word.lower().equals(word.toLowerCase()));
    final results = await query.get();
    return results.isNotEmpty;
  }
}

@Riverpod(keepAlive: true)
UserWordRepository userWordRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return UserWordRepository(database);
}
