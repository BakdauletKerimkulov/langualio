import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../routing/app_router.dart';
import '../application/quiz_home_notifier.dart';
import '../application/word_quiz_notifier.dart';
import '../domain/quiz_session.dart';
import '../domain/word_entry.dart';
import 'quiz_completion_view.dart';
import 'widgets/quiz_empty_state.dart';
import 'widgets/quiz_language_selector.dart';
import 'widgets/quiz_progress_card.dart';

class WordQuizHomeScreen extends ConsumerWidget {
  const WordQuizHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(wordQuizNotifierProvider);
    final homeState = ref.watch(quizHomeNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: quizAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.p24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  gapH16,
                  Text(
                    'Не удалось загрузить слова',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  gapH8,
                  TextButton(
                    onPressed: () => ref.invalidate(wordQuizNotifierProvider),
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          ),
          data: (_) {
            if (!homeState.hasWords) {
              return const QuizEmptyState();
            }
            if (homeState.isFinished) {
              return QuizCompletionView(
                correctCount: homeState.correctCount,
                totalWords: homeState.totalWords,
                mistakes: homeState.mistakes,
                onDone: () => ref.invalidate(wordQuizNotifierProvider),
              );
            }
            return _QuizHomeContent(homeState: homeState);
          },
        ),
      ),
    );
  }
}

class _QuizHomeContent extends ConsumerWidget {
  const _QuizHomeContent({required this.homeState});

  final QuizHomeState homeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = homeState.languageDirection;
    final isEnToRu = direction == LanguageDirection.enToRu;
    final progress = homeState.totalWords > 0
        ? homeState.completedCount / homeState.totalWords
        : 0.0;
    final hasStarted = homeState.completedCount > 0;

    final session = ref.watch(wordQuizNotifierProvider).valueOrNull;
    final userWordCount = session?.todayWords
            .where((w) => w.source == WordSource.user)
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sizes.p24,
        Sizes.p48,
        Sizes.p24,
        Sizes.p24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Слова дня',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (userWordCount > 0) ...[
            gapH4,
            Text(
              '$userWordCount своих слов',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          gapH32,
          QuizLanguageSelector(
            isEnToRu: isEnToRu,
            onSwap: () {
              final newDirection = isEnToRu
                  ? LanguageDirection.ruToEn
                  : LanguageDirection.enToRu;
              ref
                  .read(quizHomeNotifierProvider.notifier)
                  .switchDirection(newDirection);
            },
          ),
          gapH32,
          QuizProgressCard(
            completedCount: homeState.completedCount,
            totalWords: homeState.totalWords,
            progress: progress,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(AppRoute.addWord.name),
            icon: const Icon(Icons.add),
            label: const Text('Добавить слово'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: Sizes.p12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p16),
              ),
            ),
          ),
          gapH12,
          FilledButton(
            onPressed: () => context.pushNamed(AppRoute.quiz.name),
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
            child: Text(hasStarted ? 'Продолжить' : 'Начать'),
          ),
          gapH16,
        ],
      ),
    );
  }
}
