import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/assessment_repository.dart';
import '../data/question_bank.dart';
import '../domain/assessment_question.dart';
import '../domain/assessment_result.dart';
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
      // Last question — store answer and submit to server
      state = state.copyWith(answers: newAnswers, isSaving: true);
      _completeOnServer(newAnswers);
    }
  }

  /// Sends answers to server RPC which validates, computes level,
  /// and updates the profile.
  Future<void> _completeOnServer(Map<int, String> answers) async {
    final result = await ref
        .read(assessmentRepositoryProvider)
        .completeAssessment(
          questions: questionBank,
          answers: answers,
        );

    state = state.copyWith(isSaving: false, result: result);
  }

  /// Called from ResultView "Continue" button — updates onboarding state.
  void completeOnboarding() {
    final result = state.result;
    if (result == null) return;
    ref
        .read(onboardingStateNotifierProvider.notifier)
        .markCompleted(result.level);
  }
}
