import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.height = 16,
    this.color = AppColors.primary,
    this.backgroundColor,
    this.borderColor,
    this.showStripes = false,
  });

  final double progress;
  final double height;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showStripes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(height / 2),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
