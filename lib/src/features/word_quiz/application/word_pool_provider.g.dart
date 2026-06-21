// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_pool_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wordPoolHash() => r'04826fd85cbc1cd8941fdcbd6d1800e1d375e308';

/// Merges asset words and user Drift words into a single quiz pool.
/// Deduplicates by `word` field (case-insensitive; user words override asset).
/// Tags user words with [WordSource.user].
///
/// Copied from [wordPool].
@ProviderFor(wordPool)
final wordPoolProvider = AutoDisposeFutureProvider<List<WordEntry>>.internal(
  wordPool,
  name: r'wordPoolProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordPoolHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WordPoolRef = AutoDisposeFutureProviderRef<List<WordEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
