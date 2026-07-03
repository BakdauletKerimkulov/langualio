import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/assessment_repository.dart';
import '../data/question_bank.dart';
import '../domain/assessment_question.dart';
import '../domain/assessment_result.dart';
import 'level_calculator.dart';
import 'onboarding_state_provider.dart';

part 'assessment_controller.g.dart';

class AssessmentState {
  const AssessmentState({
    this.currentIndex = 0,
    this.answers = const {},
    this.result,
    this.isSaving = false,
  });

  final int currentIndex;
  final Map<int, String> answers;
  final AssessmentResult? result;
  final bool isSaving;

  int get totalQuestions => questionBank.length;
  bool get isComplete => result != null;
  AssessmentQuestion get currentQuestion => questionBank[currentIndex];

  AssessmentState copyWith({
    int? currentIndex,
    Map<int, String>? answers,
    AssessmentResult? result,
    bool? isSaving,
  }) {
    return AssessmentState(
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      result: result ?? this.result,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

@riverpod
class AssessmentController extends _$AssessmentController {
  @override
  AssessmentState build() => const AssessmentState();

  void submitAnswer(String answer) {
    final newAnswers = Map<int, String>.from(state.answers);
    newAnswers[state.currentIndex] = answer;

    if (state.currentIndex < state.totalQuestions - 1) {
      // Move to next question
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        answers: newAnswers,
      );
    } else {
      // Last question — calculate result
      final result = calculateLevel(
        questions: questionBank,
        answers: newAnswers,
      );
      state = state.copyWith(answers: newAnswers, result: result);
    }
  }

  Future<void> saveAndComplete() async {
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isSaving: true);
    await ref.read(assessmentRepositoryProvider).saveResult(result.level);
    ref
        .read(onboardingStateNotifierProvider.notifier)
        .markCompleted(result.level);
  }
}
