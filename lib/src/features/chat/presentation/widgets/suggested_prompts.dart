import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class SuggestedPrompts extends StatelessWidget {
  const SuggestedPrompts({super.key, required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  static const _prompts = [
    _Prompt(
      icon: Icons.chat_bubble_outline_rounded,
      text: 'Давай попрактикуем диалог',
    ),
    _Prompt(
      icon: Icons.auto_stories_rounded,
      text: 'Объясни Present Perfect',
    ),
    _Prompt(
      icon: Icons.psychology_rounded,
      text: 'Помоги запомнить новые слова',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        gapH48,
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        gapH16,
        const Text(
          'AI Tutor',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        gapH8,
        Text(
          'Твой персональный репетитор английского',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        gapH32,
        ..._prompts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PromptCard(
                icon: p.icon,
                text: p.text,
                onTap: () => onPromptSelected(p.text),
              ),
            )),
      ],
    );
  }
}

class _Prompt {
  const _Prompt({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            gapW12,
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
