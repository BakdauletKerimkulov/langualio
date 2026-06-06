import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/word_quiz/application/word_quiz_notifier.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/quiz_session.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

/// Creates a multi-meaning word for testing.
WordEntry _makeMultiMeaningWord() => WordEntry(
      id: 'run-id',
      word: 'run',
      level: DifficultyLevel.b1,
      meanings: const [
        WordMeaning(
          partOfSpeech: PartOfSpeech.verb,
          translation: 'бежать',
          exampleEn: 'I run.',
          exampleRu: 'Я бегу.',
        ),
        WordMeaning(
          partOfSpeech: PartOfSpeech.noun,
          translation: 'пробежка',
          exampleEn: 'A good run.',
          exampleRu: 'Хорошая пробежка.',
        ),
      ],
      createdAt: DateTime.utc(2026, 6, 1),
    );

WordEntry _makeSingleMeaningWord(String id, String word, String translation) =>
    WordEntry(
      id: id,
      word: word,
      level: DifficultyLevel.a1,
      meanings: [
        WordMeaning(
          partOfSpeech: PartOfSpeech.noun,
          translation: translation,
          exampleEn: 'Example.',
          exampleRu: 'Пример.',
        ),
      ],
      createdAt: DateTime.utc(2026, 6, 1),
    );

void main() {
  group('WordQuizNotifier.generateOptions', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    /// Helper: manually injects a session state into the notifier.
    void injectSession(QuizSession session) {
      // Override the provider with a pre-built session
      container = ProviderContainer(
        overrides: [
          wordQuizNotifierProvider.overrideWith(
            () => _TestWordQuizNotifier(session),
          ),
        ],
      );
    }

    test('en→ru: correct answer is selected meaning translation (index 1)', () async {
      final multiWord = _makeMultiMeaningWord();
      final distractorWords = [
        _makeSingleMeaningWord('cat-id', 'cat', 'кошка'),
        _makeSingleMeaningWord('dog-id', 'dog', 'собака'),
        _makeSingleMeaningWord('fish-id', 'fish', 'рыба'),
      ];
      final allWords = [multiWord, ...distractorWords];

      final session = QuizSession(
        todayWords: allWords,
        quizDay: DateTime.utc(2026, 6, 1),
        languageDirection: LanguageDirection.enToRu,
        selectedMeaningIndexes: const {'run-id': 1}, // noun: пробежка
      );
      injectSession(session);

      // Wait for the async build to complete
      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      // Correct answer must be 'пробежка' (index 1), not 'бежать' (index 0)
      expect(options, contains('пробежка'));
    });

    test('en→ru: correct answer is selected meaning translation (index 0)', () async {
      final multiWord = _makeMultiMeaningWord();
      final distractorWords = [
        _makeSingleMeaningWord('cat-id', 'cat', 'кошка'),
        _makeSingleMeaningWord('dog-id', 'dog', 'собака'),
        _makeSingleMeaningWord('fish-id', 'fish', 'рыба'),
      ];
      final allWords = [multiWord, ...distractorWords];

      final session = QuizSession(
        todayWords: allWords,
        quizDay: DateTime.utc(2026, 6, 1),
        languageDirection: LanguageDirection.enToRu,
        selectedMeaningIndexes: const {'run-id': 0}, // verb: бежать
      );
      injectSession(session);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      expect(options, contains('бежать'));
    });

    test('ru→en: correct answer is always the English word', () async {
      final multiWord = _makeMultiMeaningWord();
      final distractorWords = [
        _makeSingleMeaningWord('cat-id', 'cat', 'кошка'),
        _makeSingleMeaningWord('dog-id', 'dog', 'собака'),
        _makeSingleMeaningWord('fish-id', 'fish', 'рыба'),
      ];
      final allWords = [multiWord, ...distractorWords];

      final session = QuizSession(
        todayWords: allWords,
        quizDay: DateTime.utc(2026, 6, 1),
        languageDirection: LanguageDirection.ruToEn,
        selectedMeaningIndexes: const {'run-id': 1},
      );
      injectSession(session);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      expect(options, contains('run'));
    });

    test('defaults to index 0 when word not in selectedMeaningIndexes', () async {
      final multiWord = _makeMultiMeaningWord();
      final distractorWords = [
        _makeSingleMeaningWord('cat-id', 'cat', 'кошка'),
        _makeSingleMeaningWord('dog-id', 'dog', 'собака'),
        _makeSingleMeaningWord('fish-id', 'fish', 'рыба'),
      ];
      final allWords = [multiWord, ...distractorWords];

      final session = QuizSession(
        todayWords: allWords,
        quizDay: DateTime.utc(2026, 6, 1),
        languageDirection: LanguageDirection.enToRu,
        selectedMeaningIndexes: const {}, // empty — should default to 0
      );
      injectSession(session);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      expect(options, contains('бежать'));
    });
  });
}

/// Test-only subclass that skips the async build() and injects state directly.
class _TestWordQuizNotifier extends WordQuizNotifier {
  _TestWordQuizNotifier(this._session);
  final QuizSession _session;

  @override
  Future<QuizSession> build() async => _session;
}
