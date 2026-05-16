import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../../../shared/common_widgets/section_header.dart';
import 'level_progress.dart';
import 'streak_banner.dart';
import 'goal_card.dart';

class HomeActiveView extends StatelessWidget {
  const HomeActiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LevelProgress(level: 7, currentXp: 340, targetXp: 500),
        gapH32,
        const StreakBanner(days: 5),
        gapH32,
        _QuickActions(),
        gapH32,
        const SectionHeader(title: 'Daily Goals'),
        gapH16,
        const GoalCard(title: 'Learn 10 new words', xp: 20, isCompleted: true),
        gapH12,
        const GoalCard(title: 'Complete 1 grammar rule', xp: 15, isCompleted: false),
        gapH12,
        const GoalCard(title: 'Pass a quiz perfectly', xp: 30, isCompleted: false),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.play_arrow_rounded,
            label: 'Practice\nWords',
            color: AppColors.primary,
            iconBgColor: Colors.white.withValues(alpha: 0.2),
            textColor: Colors.white,
            onTap: () {},
          ),
        ),
        gapW16,
        Expanded(
          child: _ActionCard(
            icon: Icons.menu_book_rounded,
            label: 'Grammar\nRules',
            color: AppColors.surface,
            iconBgColor: AppColors.successLight,
            iconColor: AppColors.success,
            textColor: AppColors.textPrimary,
            hasBorder: true,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBgColor,
    required this.textColor,
    required this.onTap,
    this.iconColor = Colors.white,
    this.hasBorder = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconBgColor;
  final Color iconColor;
  final Color textColor;
  final bool hasBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: hasBorder ? Border.all(color: AppColors.borderLight) : null,
          boxShadow: hasBorder
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            gapH12,
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
