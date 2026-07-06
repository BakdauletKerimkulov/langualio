import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/assessment_controller.dart';
import 'widgets/assessment_progress_bar.dart';
import 'widgets/question_card.dart';
import 'widgets/result_view.dart';

class AssessmentScreen extends ConsumerWidget {
  const AssessmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentControllerProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: state.isComplete
              ? ResultView(
                  result: state.result!,
                  isSaving: state.isSaving,
                  onContinue: () => ref
                      .read(assessmentControllerProvider.notifier)
                      .saveAndComplete(),
                )
              : _QuestionView(state: state),
        ),
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.state});

  final AssessmentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(Sizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          gapH16,
          const Text(
            'Определение уровня',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          gapH24,
          AssessmentProgressBar(
            current: state.currentIndex,
            total: state.totalQuestions,
          ),
          gapH32,
          Expanded(
            child: SingleChildScrollView(
              child: QuestionCard(
                key: ValueKey(state.currentIndex),
                question: state.currentQuestion,
                onAnswer: (answer) => ref
                    .read(assessmentControllerProvider.notifier)
                    .submitAnswer(answer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
