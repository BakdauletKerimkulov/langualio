import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

void main() {
  group('WordEntry', () {
    WordEntry createTestEntry() => WordEntry(
      id: 'test-id',
      word: 'run',
      ipa: '/rʌn/',
      level: DifficultyLevel.b1,
      meanings: const [
        WordMeaning(
          partOfSpeech: PartOfSpeech.verb,
          translation: 'бежать',
          exampleEn: 'I run every morning.',
          exampleRu: 'Я бегаю каждое утро.',
        ),
        WordMeaning(
          partOfSpeech: PartOfSpeech.noun,
          translation: 'пробежка',
          exampleEn: 'I went for a run.',
          exampleRu: 'Я пошёл на пробежку.',
        ),
      ],
      createdAt: DateTime.utc(2026, 6, 1),
    );

    test('creates with multiple meanings', () {
      final entry = createTestEntry();
      expect(entry.word, 'run');
      expect(entry.meanings, hasLength(2));
      expect(entry.meanings[0].translation, 'бежать');
      expect(entry.meanings[1].translation, 'пробежка');
    });

    test('convenience getters return first meaning data', () {
      final entry = createTestEntry();
      expect(entry.primaryTranslation, 'бежать');
      expect(entry.primaryPartOfSpeech, PartOfSpeech.verb);
    });

    test('JSON round-trip with snake_case keys', () {
      final entry = createTestEntry();
      final json = entry.toJson();

      expect(json['word'], 'run');
      expect(json['meanings'], isList);
      expect(json['meanings'], hasLength(2));

      final firstMeaning = json['meanings'][0] as Map<String, dynamic>;
      expect(firstMeaning['part_of_speech'], 'verb');
      expect(firstMeaning['translation'], 'бежать');

      // Round-trip
      final restored = WordEntry.fromJson(json);
      expect(restored.word, entry.word);
      expect(restored.meanings.length, entry.meanings.length);
      expect(restored.meanings[0].translation, 'бежать');
      expect(restored.meanings[1].translation, 'пробежка');
    });

    test('fromJson deserializes DB-style response', () {
      final json = {
        'id': 'abc',
        'word': 'cat',
        'ipa': '/kæt/',
        'level': 'a1',
        'meanings': [
          {
            'part_of_speech': 'noun',
            'translation': 'кошка',
            'alternative_translations': <String>[],
            'example_en': 'I have a cat.',
            'example_ru': 'У меня есть кошка.',
          },
        ],
        'tags': <String>[],
        'created_at': '2026-06-01T00:00:00.000Z',
      };
      final entry = WordEntry.fromJson(json);
      expect(entry.word, 'cat');
      expect(entry.meanings, hasLength(1));
      expect(entry.meanings[0].partOfSpeech, PartOfSpeech.noun);
      expect(entry.primaryTranslation, 'кошка');
    });

    test('creates with null createdAt (asset words)', () {
      final entry = WordEntry(
        id: 'b1_ability',
        word: 'ability',
        level: DifficultyLevel.b1,
        meanings: const [
          WordMeaning(
            partOfSpeech: PartOfSpeech.noun,
            translation: 'способность',
            exampleEn: 'She has the ability to learn quickly.',
            exampleRu: 'Она обладает способностью быстро учиться.',
          ),
        ],
      );
      expect(entry.createdAt, isNull);
      expect(entry.word, 'ability');
    });

    test('JSON round-trip with null createdAt', () {
      final entry = WordEntry(
        id: 'b1_ability',
        word: 'ability',
        level: DifficultyLevel.b1,
        meanings: const [
          WordMeaning(
            partOfSpeech: PartOfSpeech.noun,
            translation: 'способность',
            exampleEn: 'She has the ability to learn quickly.',
            exampleRu: 'Она обладает способностью быстро учиться.',
          ),
        ],
      );
      final json = entry.toJson();
      expect(json['created_at'], isNull);

      final restored = WordEntry.fromJson(json);
      expect(restored.createdAt, isNull);
      expect(restored.word, 'ability');
      expect(restored.id, 'b1_ability');
    });

    test('fromJson with null created_at (asset format)', () {
      final json = {
        'id': 'b1_ability',
        'word': 'ability',
        'level': 'b1',
        'meanings': [
          {
            'part_of_speech': 'noun',
            'translation': 'способность',
            'alternative_translations': <String>[],
            'example_en': 'She has the ability to learn quickly.',
            'example_ru': 'Она обладает способностью быстро учиться.',
          },
        ],
        'tags': <String>[],
        'created_at': null,
      };
      final entry = WordEntry.fromJson(json);
      expect(entry.createdAt, isNull);
      expect(entry.word, 'ability');
    });

    test('keeps non-meaning fields intact', () {
      final entry = createTestEntry();
      expect(entry.id, 'test-id');
      expect(entry.ipa, '/rʌn/');
      expect(entry.level, DifficultyLevel.b1);
      expect(entry.tags, isEmpty);
      expect(entry.status, isNull);
      expect(entry.createdBy, isNull);
    });
  });
}
