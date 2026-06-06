import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../word_quiz/domain/word_entry.dart';

class WordListTile extends StatelessWidget {
  const WordListTile({super.key, required this.entry, required this.onTap});

  final WordEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = entry.level.name.toUpperCase();
    final status = entry.status ?? 'draft';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Sizes.p16,
        vertical: Sizes.p4,
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          entry.word,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.primaryTranslation,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            gapH4,
            Text(
              _formatDate(entry.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LevelBadge(level: level),
            gapW8,
            _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  Color get _color => switch (level) {
    'A1' || 'A2' => AppColors.success,
    'B1' || 'B2' => AppColors.warning,
    'C1' || 'C2' => AppColors.primary,
    _ => AppColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Sizes.p4),
      ),
      child: Text(
        level,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color get _color => switch (status) {
    'published' => AppColors.success,
    'draft' => AppColors.warning,
    'archived' => AppColors.textTertiary,
    _ => AppColors.textTertiary,
  };

  String get _label => switch (status) {
    'published' => 'Опубл.',
    'draft' => 'Черновик',
    'archived' => 'Архив',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Sizes.p4),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
