import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/grammar_item.dart';

part 'grammar_repository.g.dart';

class GrammarRepository {
  GrammarRepository(this._client);

  final SupabaseClient _client;

  /// Fetch all grammar items with the current user's progress.
  Future<List<GrammarItem>> fetchGrammarItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final itemRows = await _client
        .from('grammar_items')
        .select()
        .order('sort_order');

    final progressRows = await _client
        .from('user_grammar_progress')
        .select()
        .eq('user_id', userId);

    return mapToGrammarItems(
      (itemRows as List).cast<Map<String, dynamic>>(),
      (progressRows as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Pure mapping — testable without Supabase.
  static List<GrammarItem> mapToGrammarItems(
    List<Map<String, dynamic>> itemRows,
    List<Map<String, dynamic>> progressRows,
  ) {
    final progressByGrammarId = <String, Map<String, dynamic>>{};
    for (final row in progressRows) {
      progressByGrammarId[row['grammar_id'] as String] = row;
    }

    return itemRows.map((row) {
      final id = row['id'] as String;
      final progress = progressByGrammarId[id];

      final statusStr = progress?['status'] as String? ?? 'locked';
      final status = GrammarStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => GrammarStatus.locked,
      );

      final rulesMastered = progress?['rules_mastered'] as int? ?? 0;
      final totalRules = progress?['total_rules'] as int? ?? 0;

      final examplesJson = row['examples'] as List? ?? [];

      return GrammarItem(
        id: id,
        category: row['category'] as String,
        title: row['title'] as String,
        summary: row['summary'] as String? ?? '',
        formula: row['formula'] as String? ?? '',
        status: status,
        rulesMastered: '$rulesMastered/$totalRules',
        examples: examplesJson.map((e) {
          final map = e as Map<String, dynamic>;
          return GrammarExample(
            before: map['before'] as String? ?? '',
            highlight: map['highlight'] as String? ?? '',
            after: map['after'] as String? ?? '',
          );
        }).toList(),
      );
    }).toList();
  }
}

@Riverpod(keepAlive: true)
GrammarRepository grammarRepository(Ref ref) {
  return GrammarRepository(
    ref.watch(supabaseClientProvider),
  );
}
