import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/home/data/home_repository.dart';

/// Fake SupabaseClient is not needed for unit-testing the mapping logic.
/// We test the pure mapping functions directly.
void main() {
  group('HomeRepository mapping', () {
    test('mapProfileRow maps Supabase row to UserProgress fields', () {
      final row = <String, dynamic>{
        'id': '123',
        'nickname': 'TestUser',
        'avatar_url': 'https://example.com/avatar.png',
        'level': 3,
        'current_xp': 120,
        'target_xp': 300,
        'streak_days': 7,
      };

      final goalRows = <Map<String, dynamic>>[
        {
          'id': 'g1',
          'title': 'Learn words',
          'xp_reward': 20,
          'is_completed': true,
        },
        {
          'id': 'g2',
          'title': 'Practice grammar',
          'xp_reward': 15,
          'is_completed': false,
        },
      ];

      final progress = HomeRepository.mapToUserProgress(row, goalRows);

      expect(progress.nickname, 'TestUser');
      expect(progress.avatarUrl, 'https://example.com/avatar.png');
      expect(progress.level, 3);
      expect(progress.currentXp, 120);
      expect(progress.targetXp, 300);
      expect(progress.streakDays, 7);
      expect(progress.dailyGoals.length, 2);
      expect(progress.dailyGoals[0].title, 'Learn words');
      expect(progress.dailyGoals[0].xp, 20);
      expect(progress.dailyGoals[0].isCompleted, true);
      expect(progress.dailyGoals[1].isCompleted, false);
    });

    test('mapProfileRow handles null avatar_url', () {
      final row = <String, dynamic>{
        'id': '123',
        'nickname': 'NoAvatar',
        'avatar_url': null,
        'level': 1,
        'current_xp': 0,
        'target_xp': 500,
        'streak_days': 0,
      };

      final progress = HomeRepository.mapToUserProgress(row, []);

      expect(progress.avatarUrl, '');
      expect(progress.dailyGoals, isEmpty);
    });

    test('mapProfileRow handles empty nickname', () {
      final row = <String, dynamic>{
        'id': '123',
        'nickname': '',
        'avatar_url': null,
        'level': 1,
        'current_xp': 0,
        'target_xp': 500,
        'streak_days': 0,
      };

      final progress = HomeRepository.mapToUserProgress(row, []);

      expect(progress.nickname, '');
    });
  });
}
