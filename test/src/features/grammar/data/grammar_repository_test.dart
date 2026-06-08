import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/grammar/data/grammar_repository.dart';
import 'package:langualio/src/features/grammar/domain/grammar_item.dart';

void main() {
  group('GrammarRepository mapping', () {
    test('maps grammar_items + user_grammar_progress to GrammarItem list', () {
      final itemRows = <Map<String, dynamic>>[
        {
          'id': 'aaa-111',
          'category': 'Tenses',
          'title': 'Present Simple',
          'summary': 'Habits and routines.',
          'formula': 'Subject + V1',
          'examples': [
            {'before': 'She ', 'highlight': 'plays', 'after': ' tennis.'},
          ],
          'sort_order': 1,
        },
        {
          'id': 'bbb-222',
          'category': 'Modals',
          'title': 'Can / Could',
          'summary': 'Ability and permission.',
          'formula': 'Subject + can + V1',
          'examples': [],
          'sort_order': 2,
        },
      ];

      final progressRows = <Map<String, dynamic>>[
        {
          'grammar_id': 'aaa-111',
          'status': 'completed',
          'rules_mastered': 8,
          'total_rules': 8,
        },
      ];

      final items = GrammarRepository.mapToGrammarItems(itemRows, progressRows);

      expect(items.length, 2);

      // First item has progress
      expect(items[0].id, 'aaa-111');
      expect(items[0].title, 'Present Simple');
      expect(items[0].category, 'Tenses');
      expect(items[0].summary, 'Habits and routines.');
      expect(items[0].formula, 'Subject + V1');
      expect(items[0].status, GrammarStatus.completed);
      expect(items[0].rulesMastered, '8/8');
      expect(items[0].examples.length, 1);
      expect(items[0].examples[0].highlight, 'plays');

      // Second item has no progress → defaults to locked, 0/0
      expect(items[1].id, 'bbb-222');
      expect(items[1].status, GrammarStatus.locked);
      expect(items[1].rulesMastered, '0/0');
      expect(items[1].examples, isEmpty);
    });

    test('handles unlocked status correctly', () {
      final itemRows = <Map<String, dynamic>>[
        {
          'id': 'ccc-333',
          'category': 'Tenses',
          'title': 'Past Simple',
          'summary': '',
          'formula': '',
          'examples': [],
          'sort_order': 1,
        },
      ];

      final progressRows = <Map<String, dynamic>>[
        {
          'grammar_id': 'ccc-333',
          'status': 'unlocked',
          'rules_mastered': 3,
          'total_rules': 6,
        },
      ];

      final items = GrammarRepository.mapToGrammarItems(itemRows, progressRows);

      expect(items[0].status, GrammarStatus.unlocked);
      expect(items[0].rulesMastered, '3/6');
    });

    test('handles empty data', () {
      final items = GrammarRepository.mapToGrammarItems([], []);
      expect(items, isEmpty);
    });
  });
}
