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

  final String id;
  final String category;
  final String title;
  final String rulesMastered;
  final GrammarStatus status;
  final String summary;
  final String formula;
  final List<GrammarExample> examples;
}
