import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
import '../../word_quiz/data/word_generation_service.dart';
import '../../word_quiz/domain/word_entry.dart';

part 'admin_repository.g.dart';

class AdminRepository {
  AdminRepository({
    required SupabaseClient client,
    required WordGenerationService wordGenerationService,
  }) : _client = client,
       _wordGenerationService = wordGenerationService;

  final SupabaseClient _client;
  final WordGenerationService _wordGenerationService;

  /// Calls the Edge Function to generate a WordEntry from a word string.
  /// Delegates to [WordGenerationService].
  Future<WordEntry> generateWordEntry(String word) async {
    return _wordGenerationService.generateWordEntry(word);
  }

  /// Checks if a word already exists in `daily_words` (case-insensitive).
  Future<bool> checkDuplicateWord(String word) async {
    final response = await _client
        .from('daily_words')
        .select('id')
        .ilike('word', word.trim())
        .limit(1);
    return (response as List).isNotEmpty;
  }

  /// Inserts a new word into `daily_words`.
  Future<void> createWord(WordEntry entry, {required String status}) async {
    final userId = _client.auth.currentUser?.id;
    final json = entry.toJson();
    final row = <String, dynamic>{
      'word': json['word'],
      'ipa': json['ipa'],
      'level': json['level'],
      'meanings': json['meanings'],
      'topic': json['topic'],
      'tags': json['tags'],
      'status': status,
      'created_by': userId,
    };

    await _client.from('daily_words').insert(row);
    log(
      'Word created: ${entry.word} (status: $status)',
      name: 'AdminRepository',
    );
  }

  /// Fetches words from `daily_words`, optionally filtered by status.
  Future<List<WordEntry>> fetchWords({String? statusFilter}) async {
    var query = _client.from('daily_words').select();
    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((item) => WordEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single word by ID.
  Future<WordEntry> fetchWordById(String id) async {
    final response = await _client
        .from('daily_words')
        .select()
        .eq('id', id)
        .single();
    return WordEntry.fromJson(response);
  }

  /// Updates an existing word row.
  Future<void> updateWord(
    String id,
    WordEntry entry, {
    required String status,
  }) async {
    final json = entry.toJson();
    final updates = <String, dynamic>{
      'word': json['word'],
      'ipa': json['ipa'],
      'level': json['level'],
      'meanings': json['meanings'],
      'topic': json['topic'],
      'tags': json['tags'],
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('daily_words').update(updates).eq('id', id);
    log('Word updated: $id', name: 'AdminRepository');
  }
}

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) {
  return AdminRepository(
    client: ref.watch(supabaseClientProvider),
    wordGenerationService: ref.watch(wordGenerationServiceProvider),
  );
}
