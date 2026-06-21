import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
import '../domain/quiz_day_util.dart';
import '../domain/quiz_session.dart';
import '../domain/word_quiz_attempt.dart';

part 'quiz_attempt_repository.g.dart';

class QuizAttemptRepository {
  const QuizAttemptRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// Fetches today's attempts for the given language direction.
  Future<List<WordQuizAttempt>> fetchTodayAttempts(
    LanguageDirection direction,
  ) async {
    final quizDay = getQuizDay();
    final startOfDay = DateTime(quizDay.year, quizDay.month, quizDay.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('word_quiz_attempts')
        .select()
        .eq('language_direction', direction.value)
        .gte('answered_at', startOfDay.toIso8601String())
        .lt('answered_at', endOfDay.toIso8601String())
        .order('answered_at');

    return (response as List)
        .map((item) => WordQuizAttempt.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Saves an attempt to Supabase.
  Future<void> saveAttempt(WordQuizAttempt attempt) async {
    try {
      await _client.from('word_quiz_attempts').insert(attempt.toJson());
    } catch (e) {
      log(
        'Failed to save attempt: $e',
        name: 'QuizAttemptRepository',
      );
    }
  }

  /// Calls the server-side `upsert_word_learning_progress` RPC.
  Future<void> updateLearningProgress({
    required String wordId,
    required DateTime correctDate,
  }) async {
    try {
      await _client.rpc(
        'upsert_word_learning_progress',
        params: {
          'p_word_id': wordId,
          'p_correct_date': dateToString(correctDate),
        },
      );
    } catch (e) {
      log(
        'Failed to update learning progress: $e',
        name: 'QuizAttemptRepository',
      );
    }
  }
}

@Riverpod(keepAlive: true)
QuizAttemptRepository quizAttemptRepository(Ref ref) {
  return QuizAttemptRepository(client: ref.watch(supabaseClientProvider));
}
