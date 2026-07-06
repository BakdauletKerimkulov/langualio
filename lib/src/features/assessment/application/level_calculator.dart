import '../domain/assessment_question.dart';
import '../domain/assessment_result.dart';

/// Determines the user's CEFR level based on their answers.
///
/// Algorithm: user's level is the highest X where they correctly answered
/// ≥80% of questions at level X and below, and <60% of questions above X
/// (or there are no questions above X).
///
/// If no level fits, returns A1.
AssessmentResult calculateLevel({
  required List<AssessmentQuestion> questions,
  required Map<int, String> answers,
}) {
  // Count correct answers per level
  final correctByLevel = <CefrLevel, int>{};
  final totalByLevel = <CefrLevel, int>{};
  var totalCorrect = 0;

  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final level = question.level;
    totalByLevel[level] = (totalByLevel[level] ?? 0) + 1;

    final userAnswer = answers[i];
    if (userAnswer != null && _isCorrect(userAnswer, question.correctAnswer)) {
      correctByLevel[level] = (correctByLevel[level] ?? 0) + 1;
      totalCorrect++;
    }
  }

  // Find the highest level where the user meets the threshold
  CefrLevel determinedLevel = CefrLevel.a1;

  for (final level in CefrLevel.values) {
    final correctAtOrBelow = _correctAtOrBelow(level, correctByLevel);
    final totalAtOrBelow = _totalAtOrBelow(level, totalByLevel);

    if (totalAtOrBelow == 0) continue;

    final ratioAtOrBelow = correctAtOrBelow / totalAtOrBelow;

    // Check if user passes the threshold for this level (≥80%)
    if (ratioAtOrBelow < 0.8) continue;

    // Check above: <60% correct on levels above (or no questions above)
    final correctAbove = _correctAbove(level, correctByLevel);
    final totalAbove = _totalAbove(level, totalByLevel);

    if (totalAbove == 0 || correctAbove / totalAbove < 0.6) {
      determinedLevel = level;
    }
  }

  return AssessmentResult(
    level: determinedLevel,
    correctAnswers: totalCorrect,
    totalQuestions: questions.length,
    correctByLevel: correctByLevel,
  );
}

bool _isCorrect(String userAnswer, String correctAnswer) {
  return userAnswer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
}

int _correctAtOrBelow(CefrLevel level, Map<CefrLevel, int> correctByLevel) {
  var count = 0;
  for (final l in CefrLevel.values) {
    if (l.dbValue > level.dbValue) break;
    count += correctByLevel[l] ?? 0;
  }
  return count;
}

int _totalAtOrBelow(CefrLevel level, Map<CefrLevel, int> totalByLevel) {
  var count = 0;
  for (final l in CefrLevel.values) {
    if (l.dbValue > level.dbValue) break;
    count += totalByLevel[l] ?? 0;
  }
  return count;
}

int _correctAbove(CefrLevel level, Map<CefrLevel, int> correctByLevel) {
  var count = 0;
  for (final l in CefrLevel.values) {
    if (l.dbValue <= level.dbValue) continue;
    count += correctByLevel[l] ?? 0;
  }
  return count;
}

int _totalAbove(CefrLevel level, Map<CefrLevel, int> totalByLevel) {
  var count = 0;
  for (final l in CefrLevel.values) {
    if (l.dbValue <= level.dbValue) continue;
    count += totalByLevel[l] ?? 0;
  }
  return count;
}
