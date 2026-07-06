enum QuestionType { multipleChoice, fillBlank }

enum Discipline { grammar, reading, listening }

enum CefrLevel {
  a1(1, 'A1'),
  a2(2, 'A2'),
  b1(3, 'B1'),
  b2(4, 'B2'),
  c1(5, 'C1');

  const CefrLevel(this.dbValue, this.label);

  /// Integer value stored in the database (1=A1, 2=A2, ..., 5=C1).
  final int dbValue;
  final String label;

  String get description => switch (this) {
        CefrLevel.a1 =>
          'Ты понимаешь простые фразы и можешь представиться. Отличное начало!',
        CefrLevel.a2 =>
          'Ты можешь общаться в простых бытовых ситуациях — магазин, кафе, транспорт.',
        CefrLevel.b1 =>
          'Ты можешь общаться в большинстве повседневных ситуаций и понимаешь основную мысль текстов.',
        CefrLevel.b2 =>
          'Ты свободно общаешься на разные темы и понимаешь сложные тексты.',
        CefrLevel.c1 =>
          'Ты ��ладеешь языком на продвинутом уровне — понимаешь нюансы и можешь выражать сложные мысли.',
      };
}

class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.discipline,
    required this.level,
    required this.options,
    required this.correctAnswer,
    this.context,
  });

  final String id;
  final String text;
  final QuestionType type;
  final Discipline discipline;
  final CefrLevel level;
  final List<String> options;
  final String correctAnswer;
  final String? context;
}
