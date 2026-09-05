import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/admin/application/admin_word_list.dart';
import 'package:langualio/src/features/admin/data/admin_repository.dart';
import 'package:langualio/src/features/word_quiz/domain/part_of_speech.dart';
import 'package:langualio/src/features/word_quiz/domain/word_entry.dart';
import 'package:langualio/src/features/word_quiz/domain/word_meaning.dart';

WordEntry _makeEntry(String word) => WordEntry(
  id: word,
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

/// Records the filter it was called with; declaring [noSuchMethod] lets us
/// implement only the member the controller actually uses.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository(this._words, {this.failure});

  final List<WordEntry> _words;
  final Object? failure;
  final filters = <String?>[];

  @override
  Future<List<WordEntry>> fetchWords({String? statusFilter}) async {
    filters.add(statusFilter);
    if (failure != null) throw failure!;
    return _words;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AdminWordList', () {
    test('build() does not read state before the provider is initialized', () {
      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(
            _FakeAdminRepository([_makeEntry('ability')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(adminWordListProvider);

      expect(state.isLoading, true);
      expect(state.words, isEmpty);
      expect(state.activeFilter, isNull);
      expect(state.error, isNull);
    });

    test('build() loads words with no filter', () async {
      final repository = _FakeAdminRepository([_makeEntry('ability')]);
      final container = ProviderContainer(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      container.read(adminWordListProvider);
      await container.read(adminWordListProvider.notifier).refresh();

      final state = container.read(adminWordListProvider);
      expect(state.isLoading, false);
      expect(state.words, hasLength(1));
      expect(repository.filters.first, isNull);
    });

    test('setFilter() stores the filter and reloads with it', () async {
      final repository = _FakeAdminRepository([_makeEntry('ability')]);
      final container = ProviderContainer(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adminWordListProvider.notifier);
      notifier.setFilter('draft');

      expect(container.read(adminWordListProvider).activeFilter, 'draft');
      expect(container.read(adminWordListProvider).isLoading, true);

      await notifier.refresh();
      expect(repository.filters, contains('draft'));
      expect(container.read(adminWordListProvider).isLoading, false);
    });

    test('refresh() reuses the active filter', () async {
      final repository = _FakeAdminRepository([_makeEntry('ability')]);
      final container = ProviderContainer(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adminWordListProvider.notifier);
      notifier.setFilter('published');
      await notifier.refresh();

      expect(repository.filters.last, 'published');
    });

    test('a failing fetch surfaces an error and clears loading', () async {
      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(
            _FakeAdminRepository(const [], failure: Exception('boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(adminWordListProvider);
      await container.read(adminWordListProvider.notifier).refresh();

      final state = container.read(adminWordListProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('Ошибка загрузки'));
    });
  });
}
