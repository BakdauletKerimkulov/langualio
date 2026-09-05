import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/part_of_speech.dart';
import '../domain/word_entry.dart';
import '../domain/word_meaning.dart';

part 'word_generation_service.g.dart';

/// Calls the `generate-word-entry` Edge Function to generate a [WordEntry].
/// Shared by both [AdminRepository] and [AddWordNotifier].
class WordGenerationService {
  const WordGenerationService({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  /// Generates a [WordEntry] from a word string via the Edge Function.
  /// Handles both flat (legacy) and meanings-based (new) response formats.
  ///
  /// Throws on non-200 status. The caller should catch and handle:
  /// - 401 → unauthenticated
  /// - 429 → rate limited
  /// - 502 → upstream API error
  Future<WordEntry> generateWordEntry(String word) async {
    final response = await _client.functions.invoke(
      'generate-word-entry',
      body: {'word': word},
    );

    if (response.status != 200) {
      final error = response.data is Map
          ? response.data['error']
          : 'Unknown error';
      throw WordGenerationException(
        message: error?.toString() ?? 'Unknown error',
        statusCode: response.status,
      );
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
    throw const WordGenerationException(
      message: 'Unexpected response format from generate-word-entry',
      statusCode: 500,
    );
  }

  WordEntry _convertFlatToWordEntry(Map<String, dynamic> data) {
    final meaning = WordMeaning(
      partOfSpeech: _parsePartOfSpeech(data['part_of_speech'] as String?),
      translation: data['translation'] as String? ?? '',
      alternativeTranslations: _parseStringList(
        data['alternative_translations'],
      ),
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
}

/// Exception thrown by [WordGenerationService] with HTTP status code.
class WordGenerationException implements Exception {
  const WordGenerationException({
    required this.message,
    required this.statusCode,
  });

  final String message;
  final int statusCode;

  @override
  String toString() => 'WordGenerationException($statusCode): $message';
}

@Riverpod(keepAlive: true)
WordGenerationService wordGenerationService(Ref ref) {
  return WordGenerationService(client: ref.watch(supabaseClientProvider));
}
