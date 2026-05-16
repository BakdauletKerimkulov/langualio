import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../../../shared/common_widgets/primary_button.dart';

class HomeEmptyView extends StatelessWidget {
  const HomeEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryBorder,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
                const Icon(
                  Icons.rocket_launch_rounded,
                  size: 96,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          gapH24,
          const Text(
            'Ready to level up?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          gapH8,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Start your English journey today. Learn your first 10 words and ignite your streak!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          gapH32,
          PrimaryButton(
            text: 'Start First Lesson',
            icon: Icons.play_arrow_rounded,
            isExpanded: true,
            onPressed: () {},
          ),
          gapH16,
          Text(
            'TAKES ONLY 3 MINUTES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
