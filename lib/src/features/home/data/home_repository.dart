import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/user_progress.dart';

part 'home_repository.g.dart';

class HomeRepository {
  HomeRepository(this._client);

  final SupabaseClient _client;

  /// Fetch user progress from `profiles` + `daily_goals` tables.
  Future<UserProgress> fetchUserProgress() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final profileRow = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final goalRows = await _client
        .from('daily_goals')
        .select()
        .eq('user_id', userId)
        .eq('date', today);

    return mapToUserProgress(
      profileRow,
      (goalRows as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Pure mapping — testable without Supabase.
  static UserProgress mapToUserProgress(
    Map<String, dynamic> profileRow,
    List<Map<String, dynamic>> goalRows,
  ) {
    return UserProgress(
      nickname: profileRow['nickname'] as String? ?? '',
      avatarUrl: profileRow['avatar_url'] as String? ?? '',
      level: profileRow['level'] as int? ?? 1,
      currentXp: profileRow['current_xp'] as int? ?? 0,
      targetXp: profileRow['target_xp'] as int? ?? 500,
      streakDays: profileRow['streak_days'] as int? ?? 0,
      dailyGoals: goalRows.map((row) {
        return DailyGoal(
          title: row['title'] as String,
          xp: row['xp_reward'] as int? ?? 0,
          isCompleted: row['is_completed'] as bool? ?? false,
        );
      }).toList(),
    );
  }
}

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) {
  return HomeRepository(
    ref.watch(supabaseClientProvider),
  );
}
