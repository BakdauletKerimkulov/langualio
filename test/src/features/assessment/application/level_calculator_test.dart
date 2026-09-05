import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/assessment/application/level_calculator.dart';
import 'package:langualio/src/features/assessment/data/question_bank.dart';
import 'package:langualio/src/features/assessment/domain/assessment_question.dart';

void main() {
  group('calculateLevel', () {
    test('all correct → C1', () {
      final allCorrect = <int, String>{};
      for (var i = 0; i < questionBank.length; i++) {
        allCorrect[i] = questionBank[i].correctAnswer;
      }
      final result = calculateLevel(
        questions: questionBank,
        answers: allCorrect,
      );
      expect(result.level, CefrLevel.c1);
      expect(result.correctAnswers, 12);
    });

    test('all wrong → A1', () {
      final allWrong = <int, String>{};
      for (var i = 0; i < questionBank.length; i++) {
        allWrong[i] = 'wrong_answer_xyz';
      }
      final result = calculateLevel(questions: questionBank, answers: allWrong);
      expect(result.level, CefrLevel.a1);
      expect(result.correctAnswers, 0);
    });

    test('only A1+A2 correct → A2', () {
      final answers = <int, String>{};
      for (var i = 0; i < questionBank.length; i++) {
        if (questionBank[i].level.dbValue <= CefrLevel.a2.dbValue) {
          answers[i] = questionBank[i].correctAnswer;
        } else {
          answers[i] = 'wrong';
        }
      }
      final result = calculateLevel(questions: questionBank, answers: answers);
      expect(result.level, CefrLevel.a2);
    });

    test('case-insensitive fill-in-the-blank', () {
      final answers = <int, String>{};
      for (var i = 0; i < questionBank.length; i++) {
        // Submit correct answers but with different casing/whitespace
        answers[i] = '  ${questionBank[i].correctAnswer.toUpperCase()}  ';
      }
      final result = calculateLevel(questions: questionBank, answers: answers);
      expect(result.level, CefrLevel.c1);
    });
  });
}
