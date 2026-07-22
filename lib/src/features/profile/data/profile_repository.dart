import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/user_profile.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Fetch user profile + stats from `profiles` table.
  Future<UserProfile> fetchUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return mapToUserProfile(row);
  }

  /// Fetch only the onboarding-relevant fields from `profiles`.
  Future<({bool assessmentCompleted, int? cefrLevel})> fetchOnboardingState() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final row = await _client
        .from('profiles')
        .select('assessment_completed, cefr_level')
        .eq('id', userId)
        .single();

    return (
      assessmentCompleted: row['assessment_completed'] as bool? ?? false,
      cefrLevel: row['cefr_level'] as int?,
    );
  }

  /// Pure mapping — testable without Supabase.
  static UserProfile mapToUserProfile(Map<String, dynamic> row) {
    return UserProfile(
      nickname: row['nickname'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String? ?? '',
      level: row['level'] as int? ?? 1,
      title: row['title'] as String? ?? 'Beginner',
      stats: UserStats(
        totalXp: row['current_xp'] as int? ?? 0,
        streakDays: row['streak_days'] as int? ?? 0,
        wordsLearned: row['words_learned'] as int? ?? 0,
        accuracy: row['accuracy'] as int? ?? 0,
      ),
      // Achievements system is out of scope (N2) — empty for now
      achievements: const [],
    );
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(
    ref.watch(supabaseClientProvider),
  );
}
