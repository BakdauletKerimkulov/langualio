import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/local/asset_word_repository.dart';
import '../data/local/user_word_repository.dart';
import '../domain/word_entry.dart';

part 'word_pool_provider.g.dart';

/// Merges asset words and user Drift words into a single quiz pool.
/// Deduplicates by `word` field (case-insensitive; user words override asset).
/// Tags user words with [WordSource.user].
@riverpod
Future<List<WordEntry>> wordPool(Ref ref) async {
  final assetWords = await ref.watch(assetWordsProvider.future);
  final userRepo = ref.watch(userWordRepositoryProvider);
  final userWords = await userRepo.fetchAll();

  // Tag user words with WordSource.user
  final taggedUserWords = userWords
      .map((w) => w.copyWith(source: WordSource.user))
      .toList();

  // Build lookup of user words by lowercase word
  final userWordLookup = <String, WordEntry>{};
  for (final w in taggedUserWords) {
    userWordLookup[w.word.toLowerCase()] = w;
  }

  // Merge: user words override asset words with same word (case-insensitive)
  final merged = <WordEntry>[];
  for (final asset in assetWords) {
    final key = asset.word.toLowerCase();
    if (userWordLookup.containsKey(key)) {
      // User version wins — will be added from taggedUserWords
      continue;
    }
    merged.add(asset);
  }
  merged.addAll(taggedUserWords);

  return merged;
}
