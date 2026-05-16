import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../../../shared/common_widgets/primary_button.dart';
import '../../../routing/app_router.dart';
import '../domain/grammar_item.dart';

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
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: _isLocked ? 0.7 : 1.0,
        child: Column(
          children: [
            _Header(
              item: item,
              isLocked: _isLocked,
              isCompleted: _isCompleted,
              isExpanded: isExpanded,
              onTap: _isLocked ? null : onToggle,
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _ExpandedBody(item: item),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.isLocked,
    required this.isCompleted,
    required this.isExpanded,
    this.onTap,
  });

  final GrammarItem item;
  final bool isLocked;
  final bool isCompleted;
  final bool isExpanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _StatusIcon(isCompleted: isCompleted, isLocked: isLocked),
            gapW16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isCompleted) ...[
                        gapW8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'DONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.rulesMastered} rules mastered',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLocked)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  shape: BoxShape.circle,
                ),
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.isCompleted, required this.isLocked});

  final bool isCompleted;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color borderColor;
    Widget icon;

    if (isCompleted) {
      bg = AppColors.successLight;
      borderColor = AppColors.successBorder;
      icon = Icon(Icons.check_circle, size: 24, color: AppColors.success);
    } else if (isLocked) {
      bg = AppColors.surfaceDim;
      borderColor = Colors.transparent;
      icon = Icon(Icons.lock, size: 24, color: AppColors.textHint);
    } else {
      bg = AppColors.primaryLight;
      borderColor = AppColors.primaryBorder;
      icon = Icon(Icons.auto_stories, size: 24, color: AppColors.primary);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(child: icon),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({required this.item});

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
            ...item.examples.map((ex) => Padding(
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            )),
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
