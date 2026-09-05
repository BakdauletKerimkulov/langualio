import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/core/local_storage/drift.dart';
import 'package:langualio/src/features/word_quiz/application/word_pool_provider.dart';
import 'package:langualio/src/features/word_quiz/data/local/asset_word_repository.dart';
import 'package:langualio/src/features/word_quiz/data/local/user_word_repository.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

WordEntry _makeEntry(
  String id,
  String word, {
  String translation = 'перевод',
}) => WordEntry(
  id: id,
  word: word,
  level: DifficultyLevel.b1,
  meanings: [
    WordMeaning(
      partOfSpeech: PartOfSpeech.noun,
      translation: translation,
      exampleEn: 'Example.',
      exampleRu: 'Пример.',
    ),
  ],
);

void main() {
  group('WordPoolProvider', () {
    test('merges asset and user words', () async {
      final assetWords = [
        _makeEntry('a1', 'ability'),
        _makeEntry('a2', 'achieve'),
      ];

      final db = AppDatabase(NativeDatabase.memory());
      final userRepo = UserWordRepository(db);
      await userRepo.insert(_makeEntry('', 'ephemeral'), userId: 'user-1');

      final container = ProviderContainer(
        overrides: [
          assetWordsProvider.overrideWith((ref) async => assetWords),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final pool = await container.read(wordPoolProvider.future);

      // 2 asset + 1 user = 3
      expect(pool, hasLength(3));
      expect(
        pool.map((w) => w.word),
        containsAll(['ability', 'achieve', 'ephemeral']),
      );
    });

    test(
      'user word overrides asset word with same word (case-insensitive)',
      () async {
        final assetWords = [
          _makeEntry('a1', 'ability', translation: 'asset-translation'),
          _makeEntry('a2', 'achieve'),
        ];

        final db = AppDatabase(NativeDatabase.memory());
        final userRepo = UserWordRepository(db);
        // Same word "ability" but different case
        await userRepo.insert(
          _makeEntry('', 'Ability', translation: 'user-translation'),
          userId: 'user-1',
        );

        final container = ProviderContainer(
          overrides: [
            assetWordsProvider.overrideWith((ref) async => assetWords),
            appDatabaseProvider.overrideWithValue(db),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        final pool = await container.read(wordPoolProvider.future);

        // Only 2: user's "Ability" replaced asset's "ability", plus "achieve"
        expect(pool, hasLength(2));
        final ability = pool.firstWhere(
          (w) => w.word.toLowerCase() == 'ability',
        );
        expect(ability.primaryTranslation, 'user-translation');
      },
    );

    test('user words are tagged with WordSource.user', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final userRepo = UserWordRepository(db);
      await userRepo.insert(_makeEntry('', 'serendipity'), userId: 'user-1');

      final container = ProviderContainer(
        overrides: [
          assetWordsProvider.overrideWith((ref) async => []),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final pool = await container.read(wordPoolProvider.future);

      expect(pool, hasLength(1));
      expect(pool.first.source, WordSource.user);
    });

    test('returns only asset words when no user words exist', () async {
      final assetWords = [
        _makeEntry('a1', 'ability'),
        _makeEntry('a2', 'achieve'),
      ];

      final db = AppDatabase(NativeDatabase.memory());

      final container = ProviderContainer(
        overrides: [
          assetWordsProvider.overrideWith((ref) async => assetWords),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final pool = await container.read(wordPoolProvider.future);

      expect(pool, hasLength(2));
      expect(pool.every((w) => w.source == WordSource.asset), isTrue);
    });
  });
}
