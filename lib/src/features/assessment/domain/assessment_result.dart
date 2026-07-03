import 'assessment_question.dart';

class AssessmentResult {
  const AssessmentResult({
    required this.level,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.correctByLevel,
  });

  final CefrLevel level;
  final int correctAnswers;
  final int totalQuestions;
  final Map<CefrLevel, int> correctByLevel;
}
