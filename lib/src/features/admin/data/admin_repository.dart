import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
import '../../word_quiz/domain/part_of_speech.dart';
import '../../word_quiz/domain/word_entry.dart';
import '../../word_quiz/domain/word_meaning.dart';

part 'admin_repository.g.dart';

class AdminRepository {
  AdminRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Calls the Edge Function to generate a WordEntry from a word string.
  /// Handles both flat (legacy) and meanings-based (new) response formats.
  Future<WordEntry> generateWordEntry(String word) async {
    final response = await _client.functions.invoke(
      'generate-word-entry',
      body: {'word': word},
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw Exception('Failed to generate word: $error');
    }

    final data = _extractData(response.data);

    // If the response already has 'meanings', parse directly
    if (data['meanings'] is List) {
      return WordEntry.fromJson({
        ...data,
        'id': '',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Legacy flat response: wrap into meanings array
    return _convertFlatToWordEntry(data);
  }

  Map<String, dynamic> _extractData(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData['data'] is Map<String, dynamic>) {
      return responseData['data'] as Map<String, dynamic>;
    }
    if (responseData is String) {
      final parsed = jsonDecode(responseData) as Map<String, dynamic>;
      if (parsed['data'] is Map<String, dynamic>) {
        return parsed['data'] as Map<String, dynamic>;
      }
    }
    throw Exception('Unexpected response format from generate-word-entry');
  }

  /// Converts a flat Edge Function response into a WordEntry with one meaning.
  WordEntry _convertFlatToWordEntry(Map<String, dynamic> data) {
    final meaning = WordMeaning(
      partOfSpeech: _parsePartOfSpeech(data['part_of_speech'] as String?),
      translation: data['translation'] as String? ?? '',
      alternativeTranslations: _parseStringList(data['alternative_translations']),
      definitionEn: data['definition_en'] as String?,
      definitionRu: data['definition_ru'] as String?,
      exampleEn: data['example_en'] as String? ?? '',
      exampleRu: data['example_ru'] as String? ?? '',
    );

    return WordEntry(
      id: '',
      word: data['word'] as String? ?? '',
      ipa: data['ipa'] as String?,
      level: _parseDifficultyLevel(data['level'] as String?),
      meanings: [meaning],
      topic: data['topic'] as String?,
      tags: _parseStringList(data['tags']),
      createdAt: DateTime.now(),
    );
  }

  PartOfSpeech _parsePartOfSpeech(String? value) {
    if (value == null) return PartOfSpeech.noun;
    return PartOfSpeech.values.where((e) => e.name == value).firstOrNull ??
        PartOfSpeech.noun;
  }

  DifficultyLevel _parseDifficultyLevel(String? value) {
    if (value == null) return DifficultyLevel.a1;
    return DifficultyLevel.values.where((e) => e.name == value).firstOrNull ??
        DifficultyLevel.a1;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
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
    log('Word created: ${entry.word} (status: $status)', name: 'AdminRepository');
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
  Future<void> updateWord(String id, WordEntry entry, {required String status}) async {
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
  return AdminRepository(client: ref.watch(supabaseClientProvider));
}
