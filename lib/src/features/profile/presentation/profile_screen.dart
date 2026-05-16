import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../../../shared/common_widgets/stat_card.dart';
import '../../../shared/common_widgets/section_header.dart';
import 'profile_header.dart';
import 'achievement_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      child: Column(
        children: [
          // Title bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: IconButton(
                  icon: Icon(Icons.settings, size: 20, color: AppColors.textSecondary),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          gapH32,
          const ProfileHeader(
            name: 'Alex Carter',
            level: 7,
            title: 'Explorer',
            avatarUrl:
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&h=300',
          ),
          gapH32,
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: const [
              StatCard(
                icon: Icon(Icons.bolt, size: 24, color: AppColors.primary),
                value: '3,450',
                label: 'Total XP',
              ),
              StatCard(
                icon: Icon(Icons.local_fire_department, size: 24, color: AppColors.warning),
                value: '5',
                label: 'Day Streak',
              ),
              StatCard(
                icon: Icon(Icons.psychology, size: 24, color: AppColors.success),
                value: '482',
                label: 'Words Learned',
              ),
              StatCard(
                icon: Icon(Icons.track_changes, size: 24, color: AppColors.error),
                value: '92%',
                label: 'Accuracy',
              ),
            ],
          ),
          gapH32,
          SectionHeader(
            title: 'Achievements',
            actionLabel: 'See all',
            onAction: () {},
          ),
          gapH16,
          Row(
            children: [
              Expanded(
                child: AchievementCard(
                  icon: Icons.military_tech,
                  title: 'First 100',
                  isUnlocked: true,
                  color: AppColors.gold,
                ),
              ),
              gapW16,
              Expanded(
                child: AchievementCard(
                  icon: Icons.local_fire_department,
                  title: '7-Day Streak',
                  isUnlocked: false,
                  color: AppColors.warning,
                ),
              ),
              gapW16,
              Expanded(
                child: AchievementCard(
                  icon: Icons.shield,
                  title: 'Grammar Pro',
                  isUnlocked: false,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
