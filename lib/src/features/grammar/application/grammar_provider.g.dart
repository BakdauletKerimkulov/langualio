// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grammar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filteredGrammarItemsHash() =>
    r'23f1bc57f412a155d1d347a8a203a33fb27857c0';

/// See also [filteredGrammarItems].
@ProviderFor(filteredGrammarItems)
final filteredGrammarItemsProvider =
    AutoDisposeProvider<AsyncValue<List<GrammarItem>>>.internal(
      filteredGrammarItems,
      name: r'filteredGrammarItemsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$filteredGrammarItemsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredGrammarItemsRef =
    AutoDisposeProviderRef<AsyncValue<List<GrammarItem>>>;
String _$grammarItemsNotifierHash() =>
    r'4cfdc9909f9f77836337f0e5797e8c9fc06dc697';

/// See also [GrammarItemsNotifier].
@ProviderFor(GrammarItemsNotifier)
final grammarItemsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      GrammarItemsNotifier,
      List<GrammarItem>
    >.internal(
      GrammarItemsNotifier.new,
      name: r'grammarItemsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$grammarItemsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GrammarItemsNotifier = AutoDisposeAsyncNotifier<List<GrammarItem>>;
String _$grammarFilterHash() => r'bb835b20390bc62e37df18fc3638b0f1ea3cb0e7';

/// See also [GrammarFilter].
@ProviderFor(GrammarFilter)
final grammarFilterProvider =
    AutoDisposeNotifierProvider<GrammarFilter, String>.internal(
      GrammarFilter.new,
      name: r'grammarFilterProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$grammarFilterHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GrammarFilter = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
