import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../domain/word_quiz_attempt.dart';

class QuizCompletionView extends StatelessWidget {
  const QuizCompletionView({
    super.key,
    required this.correctCount,
    required this.totalWords,
    required this.mistakes,
    required this.onDone,
  });

  final int correctCount;
  final int totalWords;
  final List<WordQuizAttempt> mistakes;
  final VoidCallback onDone;

  String get _encouragingMessage {
    final percent = totalWords > 0 ? correctCount / totalWords : 0.0;
    if (percent >= 0.9) return 'Отличный результат! 🎉';
    if (percent >= 0.7) return 'Хороший результат! 👍';
    if (percent >= 0.5) return 'Неплохо, продолжай! 💪';
    return 'Практикуйся больше! 📚';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Sizes.p24, Sizes.p48, Sizes.p24, Sizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
                border: Border.all(
                    color: AppColors.primaryBorder, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                '$correctCount/$totalWords',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          gapH16,

          // Message
          Text(
            _encouragingMessage,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          gapH8,
          Text(
            'Квиз завершён',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          gapH32,

          // Mistakes list
          if (mistakes.isNotEmpty) ...[
            Text(
              'Ошибки',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            gapH12,
            ...mistakes.map((m) => _MistakeRow(attempt: m)),
            gapH24,
          ],

          // Done button
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: Sizes.p16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  const _MistakeRow({required this.attempt});

  final WordQuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Sizes.p8),
      padding: const EdgeInsets.all(Sizes.p12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Sizes.p12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
          gapW8,
          Expanded(
            child: Text(
              attempt.selectedOption,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
