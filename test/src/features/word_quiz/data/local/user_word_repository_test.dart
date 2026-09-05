import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/core/local_storage/drift.dart';
import 'package:langualio/src/features/word_quiz/data/local/user_word_repository.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

WordEntry _makeEntry(String word) => WordEntry(
  id: '', // will be replaced by insert
  word: word,
  level: DifficultyLevel.b1,
  meanings: const [
    WordMeaning(
      partOfSpeech: PartOfSpeech.noun,
      translation: 'перевод',
      exampleEn: 'Example.',
      exampleRu: 'Пример.',
    ),
  ],
);

void main() {
  late AppDatabase db;
  late UserWordRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = UserWordRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('UserWordRepository', () {
    test('fetchAll returns empty list on fresh database', () async {
      final words = await repo.fetchAll();
      expect(words, isEmpty);
    });

    test('insert stores a word and fetchAll returns it', () async {
      await repo.insert(_makeEntry('ephemeral'), userId: 'user-123');

      final words = await repo.fetchAll();
      expect(words, hasLength(1));
      expect(words.first.word, 'ephemeral');
      expect(words.first.createdBy, 'user-123');
    });

    test('insert generates a UUID for the id field', () async {
      await repo.insert(_makeEntry('serendipity'), userId: 'user-123');

      final words = await repo.fetchAll();
      expect(words.first.id, isNotEmpty);
      expect(words.first.id, isNot(''));
      // UUID v4 format: 8-4-4-4-12 hex chars
      expect(
        words.first.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test(
      'existsByWord returns true for existing word (case-insensitive)',
      () async {
        await repo.insert(_makeEntry('Ephemeral'), userId: 'user-123');

        expect(await repo.existsByWord('ephemeral'), isTrue);
        expect(await repo.existsByWord('EPHEMERAL'), isTrue);
        expect(await repo.existsByWord('Ephemeral'), isTrue);
      },
    );

    test('existsByWord returns false for non-existing word', () async {
      expect(await repo.existsByWord('nonexistent'), isFalse);
    });

    test('multiple inserts return all words', () async {
      await repo.insert(_makeEntry('word1'), userId: 'u1');
      await repo.insert(_makeEntry('word2'), userId: 'u1');
      await repo.insert(_makeEntry('word3'), userId: 'u1');

      final words = await repo.fetchAll();
      expect(words, hasLength(3));
    });
  });
}
