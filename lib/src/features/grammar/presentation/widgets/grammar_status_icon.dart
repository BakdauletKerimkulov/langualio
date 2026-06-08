import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class GrammarStatusIcon extends StatelessWidget {
  const GrammarStatusIcon({
    super.key,
    required this.isCompleted,
    required this.isLocked,
  });

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
