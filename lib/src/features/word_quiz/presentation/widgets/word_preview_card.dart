import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/word_entry.dart';
import '../../domain/word_meaning.dart';

class WordPreviewCard extends StatelessWidget {
  const WordPreviewCard({super.key, required this.entry});

  final WordEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Sizes.p16),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(Sizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Word + IPA
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  entry.word,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (entry.ipa != null) ...[
                gapW8,
                Text(
                  entry.ipa!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          gapH8,
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Sizes.p8,
              vertical: Sizes.p4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(Sizes.p6),
            ),
            child: Text(
              entry.level.name.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          gapH16,
          // Meanings
          ...entry.meanings.map(
            (meaning) => MeaningSection(meaning: meaning),
          ),
        ],
      ),
    );
  }
}

class MeaningSection extends StatelessWidget {
  const MeaningSection({super.key, required this.meaning});

  final WordMeaning meaning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.p12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of speech
          Text(
            meaning.partOfSpeech.name,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          gapH4,
          // Translation
          Text(
            meaning.translation,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          gapH4,
          // Example EN
          Text(
            meaning.exampleEn,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          // Example RU
          Text(
            meaning.exampleRu,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
