import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
import '../domain/daily_word.dart';
import '../domain/quiz_day_util.dart';
import '../domain/quiz_session.dart';
import '../domain/word_quiz_attempt.dart';

part 'word_quiz_repository.g.dart';

class WordQuizRepository {
  WordQuizRepository({
    required SupabaseClient client,
    required LocalStorage storage,
  })  : _client = client,
        _storage = storage;

  final SupabaseClient _client;
  final LocalStorage _storage;

  static const _todayWordsKey = 'word_quiz_today_words';
  static const _todayWordsDayKey = 'word_quiz_today_day';
  static const _pendingAttemptsKey = 'word_quiz_pending_attempts';

  // ── Fetching ──

  /// Fetches today's words via the `get_todays_words` RPC.
  /// Caches result in LocalStorage and flushes any pending attempts.
  Future<List<DailyWord>> fetchTodaysWords() async {
    // Flush pending attempts opportunistically
    await _flushPendingAttempts();

    final response = await _client.rpc('get_todays_words');
    final list = (response as List)
        .map((item) => DailyWord.fromJson(item as Map<String, dynamic>))
        .toList();

    // Cache for offline use
    final quizDay = getQuizDay();
    final jsonList = list
        .map((w) => {'id': w.id, 'word_en': w.wordEn, 'word_ru': w.wordRu})
        .toList();
    await _storage.setString(_todayWordsKey, jsonEncode(jsonList));
    await _storage.setString(_todayWordsDayKey, dateToString(quizDay));

    return list;
  }

  /// Fetches all words from `daily_words` (used as distractor pool).
  Future<List<DailyWord>> fetchAllWords() async {
    final response = await _client.from('daily_words').select();
    return (response as List)
        .map((item) => DailyWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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

  // ── Writing ──

  /// Saves an attempt to Supabase. On failure, queues locally for later sync.
  Future<void> saveAttempt(WordQuizAttempt attempt) async {
    try {
      await _client.from('word_quiz_attempts').insert(attempt.toJson());
    } catch (e) {
      log('Failed to save attempt, queuing locally: $e',
          name: 'WordQuizRepository');
      await _queuePendingAttempt(attempt);
    }
  }

  /// Calls the server-side `upsert_word_learning_progress` RPC.
  Future<void> updateLearningProgress({
    required String wordId,
    required DateTime correctDate,
  }) async {
    try {
      await _client.rpc('upsert_word_learning_progress', params: {
        'p_word_id': wordId,
        'p_correct_date': dateToString(correctDate),
      });
    } catch (e) {
      log('Failed to update learning progress: $e',
          name: 'WordQuizRepository');
    }
  }

  // ── Local Cache ──

  /// Returns cached today's words if the cache matches the current quiz day.
  List<DailyWord>? getCachedTodaysWords() {
    final cachedDay = _storage.getString(_todayWordsDayKey);
    final currentDay = dateToString(getQuizDay());
    if (cachedDay != currentDay) return null;

    final raw = _storage.getString(_todayWordsKey);
    if (raw == null) return null;

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => DailyWord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Pending Attempts Queue ──

  Future<void> _queuePendingAttempt(WordQuizAttempt attempt) async {
    final pending = _loadPendingAttempts();
    pending.add(attempt.toJson());
    await _storage.setString(_pendingAttemptsKey, jsonEncode(pending));
  }

  List<Map<String, dynamic>> _loadPendingAttempts() {
    final raw = _storage.getString(_pendingAttemptsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _flushPendingAttempts() async {
    final pending = _loadPendingAttempts();
    if (pending.isEmpty) return;

    final failed = <Map<String, dynamic>>[];
    for (final attemptJson in pending) {
      try {
        await _client.from('word_quiz_attempts').insert(attemptJson);
      } catch (e) {
        log('Failed to flush pending attempt: $e',
            name: 'WordQuizRepository');
        failed.add(attemptJson);
      }
    }

    if (failed.isEmpty) {
      await _storage.remove(_pendingAttemptsKey);
    } else {
      await _storage.setString(_pendingAttemptsKey, jsonEncode(failed));
    }
  }

}

@Riverpod(keepAlive: true)
WordQuizRepository wordQuizRepository(Ref ref) {
  return WordQuizRepository(
    client: ref.watch(supabaseClientProvider),
    storage: ref.watch(localStorageProvider),
  );
}
