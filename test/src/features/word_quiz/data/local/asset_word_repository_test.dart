import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/word_quiz/data/local/asset_word_repository.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetWordRepository', () {
    late AssetWordRepository repository;

    setUp(() {
      repository = AssetWordRepository();
    });

    test('loads and deserializes b1_words.json', () async {
      // Load the actual asset file content for the test
      final jsonString = await rootBundle.loadString(
        'assets/data/b1_words.json',
      );
      final list = jsonDecode(jsonString) as List;
      expect(list, isNotEmpty);

      final words = await repository.loadWords();

      expect(words, hasLength(list.length));
      expect(words.first.id, 'b1_ability');
      expect(words.first.word, 'ability');
      expect(words.first.level, DifficultyLevel.b1);
      expect(words.first.createdAt, isNull);
      expect(words.first.meanings, isNotEmpty);
      expect(words.first.meanings.first.translation, 'способность');
      expect(words.first.meanings.first.partOfSpeech, PartOfSpeech.noun);
    });

    test('returns correctly typed list with all entries', () async {
      final words = await repository.loadWords();

      expect(words, hasLength(5));
      for (final word in words) {
        expect(word.id, startsWith('b1_'));
        expect(word.word, isNotEmpty);
        expect(word.level, DifficultyLevel.b1);
        expect(word.meanings, isNotEmpty);
        expect(word.createdAt, isNull);
      }
    });

    test('each word has valid meaning with translation and examples', () async {
      final words = await repository.loadWords();

      for (final word in words) {
        final meaning = word.meanings.first;
        expect(meaning.translation, isNotEmpty);
        expect(meaning.exampleEn, isNotEmpty);
        expect(meaning.exampleRu, isNotEmpty);
      }
    });
  });
}
