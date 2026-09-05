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
  const Achievement({required this.title, required this.isUnlocked});

  final String title;
  final bool isUnlocked;
}

class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.level,
    required this.title,
    required this.avatarUrl,
    required this.stats,
    required this.achievements,
  });

  final String nickname;
  final int level;
  final String title;
  final String avatarUrl;
  final UserStats stats;
  final List<Achievement> achievements;
}
