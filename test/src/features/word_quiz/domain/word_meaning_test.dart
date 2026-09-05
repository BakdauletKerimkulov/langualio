import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';

void main() {
  group('WordMeaning', () {
    WordMeaning createTestMeaning() => const WordMeaning(
      partOfSpeech: PartOfSpeech.verb,
      translation: 'бежать',
      exampleEn: 'I run every morning.',
      exampleRu: 'Я бегаю каждое утро.',
    );

    test('creates with required fields and defaults', () {
      final meaning = createTestMeaning();
      expect(meaning.partOfSpeech, PartOfSpeech.verb);
      expect(meaning.translation, 'бежать');
      expect(meaning.exampleEn, 'I run every morning.');
      expect(meaning.exampleRu, 'Я бегаю каждое утро.');
      expect(meaning.alternativeTranslations, isEmpty);
      expect(meaning.definitionEn, isNull);
      expect(meaning.definitionRu, isNull);
    });

    test('creates with all optional fields', () {
      const meaning = WordMeaning(
        partOfSpeech: PartOfSpeech.noun,
        translation: 'пробежка',
        alternativeTranslations: ['забег', 'бег'],
        definitionEn: 'An act of running.',
        definitionRu: 'Акт бега.',
        exampleEn: 'I went for a run.',
        exampleRu: 'Я пошёл на пробежку.',
      );
      expect(meaning.alternativeTranslations, ['забег', 'бег']);
      expect(meaning.definitionEn, 'An act of running.');
      expect(meaning.definitionRu, 'Акт бега.');
    });

    test('copyWith changes specific fields', () {
      final original = createTestMeaning();
      final modified = original.copyWith(
        translation: 'бегать',
        definitionEn: 'To move quickly on foot.',
      );
      expect(modified.translation, 'бегать');
      expect(modified.definitionEn, 'To move quickly on foot.');
      expect(modified.partOfSpeech, PartOfSpeech.verb);
      expect(modified.exampleEn, original.exampleEn);
    });

    test('JSON round-trip with snake_case keys', () {
      const meaning = WordMeaning(
        partOfSpeech: PartOfSpeech.verb,
        translation: 'бежать',
        alternativeTranslations: ['бегать'],
        definitionEn: 'To move quickly.',
        definitionRu: 'Двигаться быстро.',
        exampleEn: 'I run every day.',
        exampleRu: 'Я бегаю каждый день.',
      );

      final json = meaning.toJson();

      // Verify snake_case keys from build.yaml field_rename: snake
      expect(json['part_of_speech'], 'verb');
      expect(json['translation'], 'бежать');
      expect(json['alternative_translations'], ['бегать']);
      expect(json['definition_en'], 'To move quickly.');
      expect(json['definition_ru'], 'Двигаться быстро.');
      expect(json['example_en'], 'I run every day.');
      expect(json['example_ru'], 'Я бегаю каждый день.');

      // Round-trip
      final restored = WordMeaning.fromJson(json);
      expect(restored, meaning);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'part_of_speech': 'noun',
        'translation': 'кошка',
        'example_en': 'I have a cat.',
        'example_ru': 'У меня есть кошка.',
      };
      final meaning = WordMeaning.fromJson(json);
      expect(meaning.partOfSpeech, PartOfSpeech.noun);
      expect(meaning.alternativeTranslations, isEmpty);
      expect(meaning.definitionEn, isNull);
    });

    test('equality works', () {
      final a = createTestMeaning();
      final b = createTestMeaning();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
