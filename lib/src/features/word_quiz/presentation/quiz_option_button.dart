import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

enum QuizOptionState { idle, correct, wrong, dimmed }

class QuizOptionButton extends StatelessWidget {
  const QuizOptionButton({
    super.key,
    required this.text,
    required this.optionState,
    required this.onTap,
  });

  final String text;
  final QuizOptionState optionState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = switch (optionState) {
      QuizOptionState.idle => (
        AppColors.surface,
        AppColors.borderLight,
        AppColors.textPrimary,
      ),
      QuizOptionState.correct => (
        AppColors.successLight,
        AppColors.successBorder,
        const Color(0xFF00C853),
      ),
      QuizOptionState.wrong => (
        const Color(0x1AFF6B6B),
        AppColors.error.withValues(alpha: 0.3),
        AppColors.error,
      ),
      QuizOptionState.dimmed => (
        AppColors.surfaceDim,
        AppColors.borderLight,
        AppColors.textTertiary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.p12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.p20,
            vertical: Sizes.p16,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Sizes.p16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
