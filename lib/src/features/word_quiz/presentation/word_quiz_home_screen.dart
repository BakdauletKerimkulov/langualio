import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../application/quiz_home_notifier.dart';
import '../application/word_quiz_notifier.dart';
import '../domain/quiz_session.dart';
import 'quiz_completion_view.dart';

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
                  const Icon(Icons.error_outline, size: 48,
                      color: AppColors.error),
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
                    onPressed: () =>
                        ref.invalidate(wordQuizNotifierProvider),
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          ),
          data: (_) {
            if (!homeState.hasWords) {
              return const _EmptyState();
            }
            if (homeState.isFinished) {
              return QuizCompletionView(
                correctCount: homeState.correctCount,
                totalWords: homeState.totalWords,
                mistakes: homeState.mistakes,
                onDone: () =>
                    ref.invalidate(wordQuizNotifierProvider),
              );
            }
            return _QuizHomeContent(homeState: homeState);
          },
        ),
      ),
    );
  }
}

// ── Empty State ──

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, size: 64,
                color: AppColors.textTertiary),
            gapH24,
            Text(
              'Сегодня нет слов для изучения',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            gapH8,
            Text(
              'Загляни завтра!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quiz Home Content ──

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Sizes.p24, Sizes.p48, Sizes.p24, Sizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Слова дня',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          gapH32,

          // Language direction selector
          _LanguageSelector(
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

          // Progress card
          _ProgressCard(
            completedCount: homeState.completedCount,
            totalWords: homeState.totalWords,
            progress: progress,
          ),

          const Spacer(),

          // Start / Continue button
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

// ── Language Selector ──

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.isEnToRu,
    required this.onSwap,
  });

  final bool isEnToRu;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Sizes.p20, vertical: Sizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Sizes.p16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isEnToRu ? 'English' : 'Русский',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          gapW12,
          GestureDetector(
            onTap: onSwap,
            child: Container(
              padding: const EdgeInsets.all(Sizes.p8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(Sizes.p8),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          gapW12,
          Text(
            isEnToRu ? 'Русский' : 'English',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress Card ──

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completedCount,
    required this.totalWords,
    required this.progress,
  });

  final int completedCount;
  final int totalWords;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.p20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Sizes.p16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$completedCount/$totalWords',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          gapH12,
          ClipRRect(
            borderRadius: BorderRadius.circular(Sizes.p6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceDim,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          gapH8,
          Text(
            '$completedCount из $totalWords слов пройдено',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
