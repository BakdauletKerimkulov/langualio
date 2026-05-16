import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/constants/app_colors.dart';
import 'app_router.dart';

class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavTab(label: 'Home', icon: Icons.home_rounded, path: '/'),
    _NavTab(label: 'Grammar', icon: Icons.auto_stories_rounded, path: '/grammar'),
    _NavTab(label: 'Practice', icon: Icons.sports_esports_rounded, path: '/practice'),
    _NavTab(label: 'Profile', icon: Icons.person_rounded, path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final isHome = index == 0;
    return Scaffold(
      body: child,
      floatingActionButton: isHome
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              onPressed: () => context.pushNamed(AppRoute.chat.name),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == index;
                return _NavItem(
                  icon: tab.icon,
                  label: tab.label,
                  isActive: isActive,
                  onTap: () => context.go(tab.path),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
