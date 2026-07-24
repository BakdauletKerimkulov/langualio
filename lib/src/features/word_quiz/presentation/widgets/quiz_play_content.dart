import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../quiz_option_button.dart';

class QuizPlayContent extends StatelessWidget {
  const QuizPlayContent({
    super.key,
    required this.questionWord,
    required this.isUserWord,
    required this.answeredCount,
    required this.totalWords,
    required this.options,
    required this.getOptionState,
    required this.onOptionTap,
    required this.onClose,
  });

  final String questionWord;
  final bool isUserWord;
  final int answeredCount;
  final int totalWords;
  final List<String> options;
  final QuizOptionState Function(String) getOptionState;
  final void Function(String) onOptionTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sizes.p24,
        Sizes.p16,
        Sizes.p24,
        Sizes.p24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: close + progress
          Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
              ),
              gapW16,
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Sizes.p6),
                  child: LinearProgressIndicator(
                    value: totalWords > 0
                        ? (answeredCount + 1) / totalWords
                        : 0,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceDim,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              gapW16,
              Text(
                '${answeredCount + 1}/$totalWords',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),

          // Question word
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  questionWord,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isUserWord) ...[
                  gapH8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sizes.p12,
                      vertical: Sizes.p4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(Sizes.p12),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Text(
                      'Моё слово',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(flex: 3),

          // Options
          ...options.map(
            (option) => QuizOptionButton(
              text: option,
              optionState: getOptionState(option),
              onTap: getOptionState(option) == QuizOptionState.idle
                  ? () => onOptionTap(option)
                  : null,
            ),
          ),
          gapH16,
        ],
      ),
    );
  }
}
