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
    required this.name,
    required this.avatarUrl,
    required this.level,
    required this.currentXp,
    required this.targetXp,
    required this.streakDays,
    required this.dailyGoals,
  });

  final String name;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int targetXp;
  final int streakDays;
  final List<DailyGoal> dailyGoals;

  static const mock = UserProgress(
    name: 'Alex',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&h=300',
    level: 7,
    currentXp: 340,
    targetXp: 500,
    streakDays: 5,
    dailyGoals: [
      DailyGoal(title: 'Learn 10 new words', xp: 20, isCompleted: true),
      DailyGoal(title: 'Complete 1 grammar rule', xp: 15, isCompleted: false),
      DailyGoal(title: 'Pass a quiz perfectly', xp: 30, isCompleted: false),
    ],
  );
}
