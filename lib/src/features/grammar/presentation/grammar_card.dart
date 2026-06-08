import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/grammar_item.dart';
import 'widgets/grammar_card_header.dart';
import 'widgets/grammar_expanded_body.dart';

class GrammarCard extends StatelessWidget {
  const GrammarCard({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggle,
  });

  final GrammarItem item;
  final bool isExpanded;
  final VoidCallback onToggle;

  bool get _isLocked => item.status == GrammarStatus.locked;
  bool get _isCompleted => item.status == GrammarStatus.completed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _isLocked ? const Color(0xFFF9F9F9) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: isExpanded && !_isLocked
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: _isLocked ? 0.7 : 1.0,
        child: Column(
          children: [
            GrammarCardHeader(
              item: item,
              isLocked: _isLocked,
              isCompleted: _isCompleted,
              isExpanded: isExpanded,
              onTap: _isLocked ? null : onToggle,
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: GrammarExpandedBody(item: item),
              crossFadeState: isExpanded && !_isLocked
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
