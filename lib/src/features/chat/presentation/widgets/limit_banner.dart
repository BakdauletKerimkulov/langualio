import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class LimitBanner extends StatelessWidget {
  const LimitBanner({super.key, required this.dailyLimit});

  final int dailyLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          gapW8,
          Expanded(
            child: Text(
              'Дневной лимит исчерпан ($dailyLimit сообщений). Попробуй завтра!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
