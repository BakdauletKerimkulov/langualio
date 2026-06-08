class DailyGoal {
  const DailyGoal({
    required this.title,
    required this.xp,
    required this.isCompleted,
  });

  final String title;
  final int xp;
  final bool isCompleted;
}

class UserProgress {
  const UserProgress({
    required this.nickname,
    required this.avatarUrl,
    required this.level,
    required this.currentXp,
    required this.targetXp,
    required this.streakDays,
    required this.dailyGoals,
  });

  final String nickname;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int targetXp;
  final int streakDays;
  final List<DailyGoal> dailyGoals;

}
