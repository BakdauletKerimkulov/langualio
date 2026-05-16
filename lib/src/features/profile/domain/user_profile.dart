class UserStats {
  const UserStats({
    required this.totalXp,
    required this.streakDays,
    required this.wordsLearned,
    required this.accuracy,
  });

  final int totalXp;
  final int streakDays;
  final int wordsLearned;
  final int accuracy;
}

class Achievement {
  const Achievement({
    required this.title,
    required this.isUnlocked,
  });

  final String title;
  final bool isUnlocked;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.level,
    required this.title,
    required this.avatarUrl,
    required this.stats,
    required this.achievements,
  });

  final String name;
  final int level;
  final String title;
  final String avatarUrl;
  final UserStats stats;
  final List<Achievement> achievements;

  static const mock = UserProfile(
    name: 'Alex Carter',
    level: 7,
    title: 'Explorer',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&h=300',
    stats: UserStats(
      totalXp: 3450,
      streakDays: 5,
      wordsLearned: 482,
      accuracy: 92,
    ),
    achievements: [
      Achievement(title: 'First 100', isUnlocked: true),
      Achievement(title: '7-Day Streak', isUnlocked: false),
      Achievement(title: 'Grammar Pro', isUnlocked: false),
    ],
  );
}
