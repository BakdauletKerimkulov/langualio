import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../application/word_quiz_notifier.dart';
import '../domain/daily_word.dart';
import '../domain/quiz_session.dart';
import 'quiz_option_button.dart';

class WordQuizScreen extends ConsumerStatefulWidget {
  const WordQuizScreen({super.key});

  @override
  ConsumerState<WordQuizScreen> createState() => _WordQuizScreenState();
}

class _WordQuizScreenState extends ConsumerState<WordQuizScreen> {
  List<String> _options = [];
  String? _selectedOption;
  bool _isSubmitting = false;
  String? _correctAnswer;

  @override
  void initState() {
    super.initState();
    // Generate options after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  void _loadOptions() {
    final session = ref.read(wordQuizNotifierProvider).valueOrNull;
    if (session == null) return;

    final word = session.currentWord;
    if (word == null) return;

    final notifier = ref.read(wordQuizNotifierProvider.notifier);
    final options = notifier.generateOptions(word);

    final isEnToRu = session.languageDirection == LanguageDirection.enToRu;
    final correct = isEnToRu ? word.wordRu : word.wordEn;

    if (mounted) {
      setState(() {
        _options = options;
        _selectedOption = null;
        _correctAnswer = correct;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _onOptionTap(String option, DailyWord word) async {
    if (_isSubmitting || _selectedOption != null) return;

    final isCorrect = option == _correctAnswer;

    setState(() {
      _selectedOption = option;
      _isSubmitting = true;
    });

    // Submit answer
    await ref.read(wordQuizNotifierProvider.notifier).submitAnswer(
          wordId: word.id,
          selectedOption: option,
          isCorrect: isCorrect,
        );

    if (!mounted) return;

    // Auto-advance after delay
    final delay = isCorrect
        ? const Duration(milliseconds: 1000)
        : const Duration(milliseconds: 1500);

    await Future.delayed(delay);
    if (!mounted) return;

    // Check if quiz is finished
    final session = ref.read(wordQuizNotifierProvider).valueOrNull;
    if (session == null) return;

    if (session.isFinished) {
      // Pop back to quiz home — it will show completion view
      context.pop();
    } else {
      // Load next word's options
      _loadOptions();
    }
  }

  QuizOptionState _getOptionState(String option) {
    if (_selectedOption == null) return QuizOptionState.idle;

    if (option == _correctAnswer) return QuizOptionState.correct;
    if (option == _selectedOption) return QuizOptionState.wrong;
    return QuizOptionState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(wordQuizNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: quizAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48,
                    color: AppColors.error),
                gapH16,
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Назад'),
                ),
              ],
            ),
          ),
          data: (session) {
            final word = session.currentWord;
            if (word == null) {
              // All done — pop back
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.pop();
              });
              return const SizedBox.shrink();
            }

            final isEnToRu =
                session.languageDirection == LanguageDirection.enToRu;
            final questionWord = isEnToRu ? word.wordEn : word.wordRu;

            return _QuizPlayContent(
              questionWord: questionWord,
              answeredCount: session.answeredCount,
              totalWords: session.totalWords,
              options: _options,
              getOptionState: _getOptionState,
              onOptionTap: (option) => _onOptionTap(option, word),
              onClose: () => context.pop(),
            );
          },
        ),
      ),
    );
  }
}

// ── Quiz Play Content ──

class _QuizPlayContent extends StatelessWidget {
  const _QuizPlayContent({
    required this.questionWord,
    required this.answeredCount,
    required this.totalWords,
    required this.options,
    required this.getOptionState,
    required this.onOptionTap,
    required this.onClose,
  });

  final String questionWord;
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
          Sizes.p24, Sizes.p16, Sizes.p24, Sizes.p24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: close + progress
          Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 28),
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
                        AppColors.primary),
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
            child: Text(
              questionWord,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(flex: 3),

          // Options
          ...options.map((option) => QuizOptionButton(
                text: option,
                optionState: getOptionState(option),
                onTap: getOptionState(option) == QuizOptionState.idle
                    ? () => onOptionTap(option)
                    : null,
              )),
          gapH16,
        ],
      ),
    );
  }
}
