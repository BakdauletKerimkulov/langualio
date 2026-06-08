import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/profile/data/profile_repository.dart';

void main() {
  group('ProfileRepository mapping', () {
    test('maps profiles row to UserProfile with stats', () {
      final row = <String, dynamic>{
        'id': 'user-123',
        'nickname': 'TestUser',
        'avatar_url': 'https://example.com/avatar.png',
        'level': 5,
        'title': 'Explorer',
        'current_xp': 2500,
        'streak_days': 12,
        'words_learned': 320,
        'accuracy': 88,
      };

      final profile = ProfileRepository.mapToUserProfile(row);

      expect(profile.nickname, 'TestUser');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.level, 5);
      expect(profile.title, 'Explorer');
      expect(profile.stats.totalXp, 2500);
      expect(profile.stats.streakDays, 12);
      expect(profile.stats.wordsLearned, 320);
      expect(profile.stats.accuracy, 88);
    });

    test('handles null avatar_url and defaults', () {
      final row = <String, dynamic>{
        'id': 'user-456',
        'nickname': '',
        'avatar_url': null,
        'level': 1,
        'title': 'Beginner',
        'current_xp': 0,
        'streak_days': 0,
        'words_learned': 0,
        'accuracy': 0,
      };

      final profile = ProfileRepository.mapToUserProfile(row);

      expect(profile.avatarUrl, '');
      expect(profile.nickname, '');
      expect(profile.level, 1);
      expect(profile.title, 'Beginner');
      expect(profile.stats.totalXp, 0);
    });

    test('achievements default to empty list from DB', () {
      final row = <String, dynamic>{
        'id': 'user-789',
        'nickname': 'User',
        'avatar_url': null,
        'level': 1,
        'title': 'Beginner',
        'current_xp': 0,
        'streak_days': 0,
        'words_learned': 0,
        'accuracy': 0,
      };

      final profile = ProfileRepository.mapToUserProfile(row);

      // Achievements are out of scope (N2) — empty list for now
      expect(profile.achievements, isEmpty);
    });
  });
}
