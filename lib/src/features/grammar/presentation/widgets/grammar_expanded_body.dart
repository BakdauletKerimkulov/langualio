import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common_widgets/primary_button.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../routing/app_router.dart';
import '../../domain/grammar_item.dart';

class GrammarExpandedBody extends StatelessWidget {
  const GrammarExpandedBody({super.key, required this.item});

  final GrammarItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RULE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          gapH8,
          Text(
            item.summary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          gapH12,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(
              item.formula,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          if (item.examples.isNotEmpty) ...[
            gapH20,
            Text(
              'EXAMPLES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textTertiary,
              ),
            ),
            gapH8,
            ...item.examples.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(text: ex.before),
                        WidgetSpan(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x3300E676),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ex.highlight,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00B85C),
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: ex.after),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          gapH12,
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Practice',
                  icon: Icons.play_arrow_rounded,
                  isExpanded: true,
                  onPressed: () {},
                ),
              ),
              gapW8,
              Expanded(
                child: PrimaryButton(
                  text: 'Ask AI',
                  icon: Icons.smart_toy_rounded,
                  isExpanded: true,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  onPressed: () {
                    context.pushNamed(
                      AppRoute.chat.name,
                      extra: 'Объясни правило "${item.title}" подробнее',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
