enum GrammarStatus { completed, unlocked, locked }

class GrammarExample {
  const GrammarExample({
    required this.before,
    required this.highlight,
    required this.after,
  });

  final String before;
  final String highlight;
  final String after;
}

class GrammarItem {
  const GrammarItem({
    required this.id,
    required this.category,
    required this.title,
    required this.rulesMastered,
    required this.status,
    required this.summary,
    required this.formula,
    required this.examples,
  });

  final int id;
  final String category;
  final String title;
  final String rulesMastered;
  final GrammarStatus status;
  final String summary;
  final String formula;
  final List<GrammarExample> examples;

  static const mockItems = [
    GrammarItem(
      id: 1,
      category: 'Tenses',
      title: 'Present Simple',
      rulesMastered: '8/8',
      status: GrammarStatus.completed,
      summary: 'Used for habits, routines, and general truths.',
      formula: 'Subject + V1 (s/es)',
      examples: [
        GrammarExample(before: 'She ', highlight: 'plays', after: ' tennis every Saturday.'),
        GrammarExample(before: 'The sun ', highlight: 'rises', after: ' in the east.'),
      ],
    ),
    GrammarItem(
      id: 2,
      category: 'Tenses',
      title: 'Present Continuous',
      rulesMastered: '2/6',
      status: GrammarStatus.unlocked,
      summary: 'Used for actions happening right now or temporary situations.',
      formula: 'Subject + am/is/are + V-ing',
      examples: [
        GrammarExample(before: 'I ', highlight: 'am reading', after: ' a great book.'),
        GrammarExample(before: 'They ', highlight: 'are playing', after: ' in the garden.'),
      ],
    ),
    GrammarItem(
      id: 3,
      category: 'Modals',
      title: 'Can / Could',
      rulesMastered: '0/4',
      status: GrammarStatus.locked,
      summary: 'Express ability, possibility, or permission.',
      formula: 'Subject + can/could + V1',
      examples: [],
    ),
  ];
}
