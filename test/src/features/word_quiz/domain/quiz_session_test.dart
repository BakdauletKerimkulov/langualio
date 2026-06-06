import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/quiz_session.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

WordEntry _makeWord(String id, List<WordMeaning> meanings) => WordEntry(
      id: id,
      word: 'word_$id',
      level: DifficultyLevel.b1,
      meanings: meanings,
      createdAt: DateTime.utc(2026, 6, 1),
    );

const _verbMeaning = WordMeaning(
  partOfSpeech: PartOfSpeech.verb,
  translation: 'бежать',
  exampleEn: 'I run.',
  exampleRu: 'Я бегу.',
);

const _nounMeaning = WordMeaning(
  partOfSpeech: PartOfSpeech.noun,
  translation: 'пробежка',
  exampleEn: 'A good run.',
  exampleRu: 'Хорошая пробежка.',
);

void main() {
  group('QuizSession', () {
    test('selectedMeaningIndexes defaults to empty', () {
      final session = QuizSession(quizDay: DateTime.utc(2026, 6, 1));
      expect(session.selectedMeaningIndexes, isEmpty);
    });

    test('stores selectedMeaningIndexes for multi-meaning words', () {
      final words = [
        _makeWord('1', const [_verbMeaning, _nounMeaning]),
        _makeWord('2', const [_nounMeaning]),
      ];
      final session = QuizSession(
        todayWords: words,
        quizDay: DateTime.utc(2026, 6, 1),
        selectedMeaningIndexes: const {'1': 1, '2': 0},
      );
      expect(session.selectedMeaningIndexes['1'], 1);
      expect(session.selectedMeaningIndexes['2'], 0);
    });

    test('currentWord still returns first unanswered word', () {
      final words = [
        _makeWord('1', const [_verbMeaning]),
        _makeWord('2', const [_nounMeaning]),
      ];
      final session = QuizSession(
        todayWords: words,
        answeredWordIds: const {'1'},
        quizDay: DateTime.utc(2026, 6, 1),
      );
      expect(session.currentWord?.id, '2');
    });

    test('copyWith preserves selectedMeaningIndexes', () {
      final session = QuizSession(
        quizDay: DateTime.utc(2026, 6, 1),
        selectedMeaningIndexes: const {'1': 0},
      );
      final updated = session.copyWith(answeredWordIds: {'1'});
      expect(updated.selectedMeaningIndexes, {'1': 0});
    });

    test('selectedMeaningIndexes excluded from equality', () {
      final a = QuizSession(
        quizDay: DateTime.utc(2026, 6, 1),
        selectedMeaningIndexes: const {'1': 0},
      );
      final b = QuizSession(
        quizDay: DateTime.utc(2026, 6, 1),
        selectedMeaningIndexes: const {'1': 1},
      );
      // Same quizDay, direction, counts → equal despite different indexes
      expect(a, b);
    });
  });
}
