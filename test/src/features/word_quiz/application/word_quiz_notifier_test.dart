import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/core/local_storage/drift.dart';
import 'package:langualio/src/core/local_storage/storage_provider.dart';
import 'package:langualio/src/features/word_quiz/application/word_pool_provider.dart';
import 'package:langualio/src/features/word_quiz/application/word_quiz_notifier.dart';
import 'package:langualio/src/features/word_quiz/data/local/asset_word_repository.dart';
import 'package:langualio/src/features/word_quiz/data/quiz_attempt_repository.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/quiz_session.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';
import 'package:langualio/src/features/word_quiz/domain/word_quiz_attempt.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      container = ProviderContainer(
        overrides: [
          wordQuizNotifierProvider.overrideWith(
            () => _TestWordQuizNotifier(session),
          ),
        ],
      );
    }

    test('en→ru: correct answer is selected meaning translation (index 1)',
        () async {
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
        selectedMeaningIndexes: const {'run-id': 1},
      );
      injectSession(session);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      expect(options, contains('пробежка'));
    });

    test('en→ru: correct answer is selected meaning translation (index 0)',
        () async {
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
        selectedMeaningIndexes: const {'run-id': 0},
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

    test('defaults to index 0 when word not in selectedMeaningIndexes',
        () async {
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
        selectedMeaningIndexes: const {},
      );
      injectSession(session);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(multiWord);

      expect(options, contains('бежать'));
    });
  });

  group('WordQuizNotifier.build — local word pool', () {
    List<WordEntry> makeAssetWords() => [
          _makeSingleMeaningWord('b1_ability', 'ability', 'способность'),
          _makeSingleMeaningWord('b1_achieve', 'achieve', 'достигать'),
          _makeSingleMeaningWord('b1_advantage', 'advantage', 'преимущество'),
          _makeSingleMeaningWord('b1_afford', 'afford', 'позволить себе'),
          _makeSingleMeaningWord('b1_agree', 'agree', 'соглашаться'),
        ];

    test('loads words from word pool provider (asset + user words)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final assetWords = makeAssetWords();
      final db = AppDatabase(NativeDatabase.memory());

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          assetWordsProvider.overrideWith((ref) async => assetWords),
          appDatabaseProvider.overrideWithValue(db),
          quizAttemptRepositoryProvider.overrideWithValue(
            _FakeQuizAttemptRepository(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final session = await container.read(wordQuizNotifierProvider.future);

      expect(session.todayWords, hasLength(5));
      expect(session.todayWords.first.id, 'b1_ability');
    });

    test('falls back to empty list when word pool fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          wordPoolProvider.overrideWith(
            (ref) async => throw Exception('Pool failed'),
          ),
          quizAttemptRepositoryProvider.overrideWithValue(
            _FakeQuizAttemptRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final session = await container.read(wordQuizNotifierProvider.future);

      expect(session.todayWords, isEmpty);
    });
  });

  group('WordQuizNotifier.generateOptions — asset words only', () {
    test('returns 4 options with asset-style words (sufficient pool)',
        () async {
      final assetWords = [
        _makeSingleMeaningWord('b1_ability', 'ability', 'способность'),
        _makeSingleMeaningWord('b1_achieve', 'achieve', 'достигать'),
        _makeSingleMeaningWord('b1_advantage', 'advantage', 'преимущество'),
        _makeSingleMeaningWord('b1_afford', 'afford', 'позволить себе'),
        _makeSingleMeaningWord('b1_agree', 'agree', 'соглашаться'),
      ];

      final session = QuizSession(
        todayWords: assetWords,
        quizDay: DateTime.utc(2026, 6, 1),
        languageDirection: LanguageDirection.enToRu,
        selectedMeaningIndexes: const {'b1_ability': 0},
      );

      final container = ProviderContainer(
        overrides: [
          wordQuizNotifierProvider.overrideWith(
            () => _TestWordQuizNotifier(session),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(wordQuizNotifierProvider.future);
      final notifier = container.read(wordQuizNotifierProvider.notifier);
      final options = notifier.generateOptions(assetWords.first);

      expect(options, hasLength(4));
      expect(options, contains('способность'));
    });
  });
}

/// Fake attempt repository that returns empty results.
class _FakeQuizAttemptRepository implements QuizAttemptRepository {
  @override
  Future<List<WordQuizAttempt>> fetchTodayAttempts(
          LanguageDirection d) async =>
      [];

  @override
  Future<void> saveAttempt(WordQuizAttempt attempt) async {}

  @override
  Future<void> updateLearningProgress({
    required String wordId,
    required DateTime correctDate,
  }) async {}
}

/// Test-only subclass that skips the async build() and injects state directly.
class _TestWordQuizNotifier extends WordQuizNotifier {
  _TestWordQuizNotifier(this._session);
  final QuizSession _session;

  @override
  Future<QuizSession> build() async => _session;
}
