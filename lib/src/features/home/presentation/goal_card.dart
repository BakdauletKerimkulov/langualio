import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.title,
    required this.xp,
    required this.isCompleted,
  });

  final String title;
  final int xp;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.successLight : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? AppColors.successBorder : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const Icon(Icons.bolt, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '$xp',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
