import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:langualio/src/core/language/string_hardcoded.dart';
import 'package:langualio/src/routing/app_router.dart';

import '../../../core/common_widgets/section_header.dart';
import '../../../core/common_widgets/stat_card.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../admin/application/admin_provider.dart';
import '../application/profile_provider.dart';
import '../domain/user_profile.dart';
import 'achievement_card.dart';
import 'profile_header.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final profileAsync = ref.watch(userProfileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile'.hardcoded,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        leading: isAdmin
            ? IconButton(
                onPressed: () => context.pushNamed(AppRoute.admin.name),
                icon: Icon(Icons.admin_panel_settings),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () => context.goNamed(AppRoute.settings.name),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _ProfileBody(profile: profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              gapH16,
              FilledButton(
                onPressed: () => ref.invalidate(userProfileNotifierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      child: Column(
        children: [
          ProfileHeader(
            nickname: profile.nickname,
            level: profile.level,
            title: profile.title,
            avatarUrl: profile.avatarUrl,
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
            children: [
              StatCard(
                icon: Icon(Icons.bolt, size: 24, color: AppColors.primary),
                value: '${profile.stats.totalXp}',
                label: 'Total XP',
              ),
              StatCard(
                icon: Icon(
                  Icons.local_fire_department,
                  size: 24,
                  color: AppColors.warning,
                ),
                value: '${profile.stats.streakDays}',
                label: 'Day Streak',
              ),
              StatCard(
                icon: Icon(
                  Icons.psychology,
                  size: 24,
                  color: AppColors.success,
                ),
                value: '${profile.stats.wordsLearned}',
                label: 'Words Learned',
              ),
              StatCard(
                icon: Icon(
                  Icons.track_changes,
                  size: 24,
                  color: AppColors.error,
                ),
                value: '${profile.stats.accuracy}%',
                label: 'Accuracy',
              ),
            ],
          ),
          gapH32,
          if (profile.achievements.isNotEmpty) ...[
            SectionHeader(
              title: 'Achievements',
              actionLabel: 'See all',
              onAction: () {},
            ),
            gapH16,
            Row(
              children: profile.achievements.map((a) {
                return Expanded(
                  child: AchievementCard(
                    icon: Icons.military_tech,
                    title: a.title,
                    isUnlocked: a.isUnlocked,
                    color: AppColors.gold,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
