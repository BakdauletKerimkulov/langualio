import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../application/home_provider.dart';
import 'home_active_view.dart';
import 'home_empty_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Toggle to preview empty state (will be replaced with real data)
  bool _isEmpty = false;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(userProgressNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(
            name: progress.name,
            avatarUrl: progress.avatarUrl,
            streak: _isEmpty ? 0 : progress.streakDays,
            onAvatarTap: () => setState(() => _isEmpty = !_isEmpty),
          ),
          gapH32,
          if (_isEmpty) const HomeEmptyView() else const HomeActiveView(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.avatarUrl,
    required this.streak,
    this.onAvatarTap,
  });

  final String name;
  final String avatarUrl;
  final int streak;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              gapW12,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HELLO,',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warningBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 20,
                color: AppColors.warning,
              ),
              gapW4,
              Text(
                '$streak',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
