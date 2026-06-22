import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/core/supabase/supabase_client.dart';
import 'package:langualio/src/features/word_quiz/application/add_word_notifier.dart';
import 'package:langualio/src/features/word_quiz/data/local/asset_word_repository.dart';
import 'package:langualio/src/features/word_quiz/data/local/user_word_repository.dart';
import 'package:langualio/src/features/word_quiz/data/word_generation_service.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

WordEntry _makeEntry(String word) => WordEntry(
      id: '',
      word: word,
      level: DifficultyLevel.b1,
      meanings: const [
        WordMeaning(
          partOfSpeech: PartOfSpeech.noun,
          translation: 'тест',
          exampleEn: 'Example.',
          exampleRu: 'Пример.',
        ),
      ],
    );

void main() {
  group('AddWordNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(addWordNotifierProvider);

      expect(state.preview, isNull);
      expect(state.isGenerating, false);
      expect(state.isSaving, false);
      expect(state.error, isNull);
      expect(state.saved, false);
    });

    test('generate: initial → generating → preview', () async {
      final generated = _makeEntry('ephemeral');
      final container = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider
              .overrideWithValue(_FakeWordGenerationService(generated)),
          assetWordsProvider.overrideWith((ref) async => <WordEntry>[]),
          userWordRepositoryProvider
              .overrideWithValue(_FakeUserWordRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);

      // Capture states during generate
      final states = <AddWordState>[];
      container.listen(addWordNotifierProvider, (_, next) {
        states.add(next);
      });

      await notifier.generate('ephemeral');

      // Should have gone through generating=true then generating=false with preview
      expect(states.any((s) => s.isGenerating), true);
      final finalState = container.read(addWordNotifierProvider);
      expect(finalState.isGenerating, false);
      expect(finalState.preview, isNotNull);
      expect(finalState.preview!.word, 'ephemeral');
      expect(finalState.error, isNull);
    });

    test('generate: duplicate in asset words → error', () async {
      final assetWord = _makeEntry('ability');
      final container = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider
              .overrideWithValue(_FakeWordGenerationService(_makeEntry('x'))),
          assetWordsProvider.overrideWith((ref) async => [assetWord]),
          userWordRepositoryProvider
              .overrideWithValue(_FakeUserWordRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);
      await notifier.generate('ability');

      final state = container.read(addWordNotifierProvider);
      expect(state.isGenerating, false);
      expect(state.preview, isNull);
      expect(state.error, contains('уже есть'));
    });

    test('generate: duplicate in user words → error', () async {
      final container = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider
              .overrideWithValue(_FakeWordGenerationService(_makeEntry('x'))),
          assetWordsProvider.overrideWith((ref) async => <WordEntry>[]),
          userWordRepositoryProvider.overrideWithValue(
            _FakeUserWordRepository(existingWords: {'custom'}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);
      await notifier.generate('custom');

      final state = container.read(addWordNotifierProvider);
      expect(state.isGenerating, false);
      expect(state.preview, isNull);
      expect(state.error, contains('уже есть'));
    });

    test('generate: service failure → error with retry possible', () async {
      final container = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider.overrideWithValue(
            _ThrowingWordGenerationService(),
          ),
          assetWordsProvider.overrideWith((ref) async => <WordEntry>[]),
          userWordRepositoryProvider
              .overrideWithValue(_FakeUserWordRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);
      await notifier.generate('ephemeral');

      final state = container.read(addWordNotifierProvider);
      expect(state.isGenerating, false);
      expect(state.preview, isNull);
      expect(state.error, isNotNull);

      // Retry should be possible (generate again)
      // Override with working service for retry
      final container2 = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider.overrideWithValue(
            _FakeWordGenerationService(_makeEntry('ephemeral')),
          ),
          assetWordsProvider.overrideWith((ref) async => <WordEntry>[]),
          userWordRepositoryProvider
              .overrideWithValue(_FakeUserWordRepository()),
        ],
      );
      addTearDown(container2.dispose);

      final notifier2 = container2.read(addWordNotifierProvider.notifier);
      await notifier2.generate('ephemeral');

      final state2 = container2.read(addWordNotifierProvider);
      expect(state2.preview, isNotNull);
      expect(state2.error, isNull);
    });

    test('generate: 429 status → rate limit error message', () async {
      final container = ProviderContainer(
        overrides: [
          wordGenerationServiceProvider.overrideWithValue(
            _RateLimitedWordGenerationService(),
          ),
          assetWordsProvider.overrideWith((ref) async => <WordEntry>[]),
          userWordRepositoryProvider
              .overrideWithValue(_FakeUserWordRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);
      await notifier.generate('ephemeral');

      final state = container.read(addWordNotifierProvider);
      expect(state.error, contains('лимит'));
    });

    test('save: preview → saving → saved', () async {
      final entry = _makeEntry('ephemeral');
      final fakeRepo = _FakeUserWordRepository();
      final container = ProviderContainer(
        overrides: [
          addWordNotifierProvider
              .overrideWith(() => _PreloadedAddWordNotifier(entry)),
          userWordRepositoryProvider.overrideWithValue(fakeRepo),
          supabaseClientProvider.overrideWithValue(
            SupabaseClient('https://test.supabase.co', 'test-key'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);

      final states = <AddWordState>[];
      container.listen(addWordNotifierProvider, (_, next) {
        states.add(next);
      });

      final result = await notifier.save();

      expect(result, true);
      expect(states.any((s) => s.isSaving), true);
      final finalState = container.read(addWordNotifierProvider);
      expect(finalState.isSaving, false);
      expect(finalState.saved, true);
      expect(finalState.error, isNull);
      expect(fakeRepo.insertedWords, hasLength(1));
    });

    test('save: returns false when no preview', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addWordNotifierProvider.notifier);
      final result = await notifier.save();

      expect(result, false);
    });
  });
}

// ── Test doubles ──

class _FakeWordGenerationService implements WordGenerationService {
  _FakeWordGenerationService(this._result);
  final WordEntry _result;

  @override
  Future<WordEntry> generateWordEntry(String word) async => _result;
}

class _ThrowingWordGenerationService implements WordGenerationService {
  @override
  Future<WordEntry> generateWordEntry(String word) async {
    throw const WordGenerationException(
      message: 'Server error',
      statusCode: 502,
    );
  }
}

class _RateLimitedWordGenerationService implements WordGenerationService {
  @override
  Future<WordEntry> generateWordEntry(String word) async {
    throw const WordGenerationException(
      message: 'Rate limited',
      statusCode: 429,
    );
  }
}

class _FakeUserWordRepository implements UserWordRepository {
  _FakeUserWordRepository({Set<String>? existingWords})
      : _existingWords = existingWords ?? {};

  final Set<String> _existingWords;
  final List<WordEntry> insertedWords = [];

  @override
  Future<List<WordEntry>> fetchAll() async => [];

  @override
  Future<void> insert(WordEntry entry, {required String userId}) async {
    insertedWords.add(entry);
  }

  @override
  Future<bool> existsByWord(String word) async {
    return _existingWords.contains(word.toLowerCase());
  }
}

/// Test-only notifier that starts with a preview already loaded.
class _PreloadedAddWordNotifier extends AddWordNotifier {
  _PreloadedAddWordNotifier(this._preview);
  final WordEntry _preview;

  @override
  AddWordState build() => AddWordState(preview: _preview);
}
