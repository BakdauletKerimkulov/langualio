import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../../../core/local_storage/shared_prefs.dart';
import '../../../core/local_storage/storage_provider.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/chat_message.dart';

part 'chat_repository.g.dart';

class ChatRepository {
  ChatRepository(this._storage, this._client);

  final LocalStorage _storage;
  final SupabaseClient _client;

  static const _key = 'chat_messages';
  static const _maxCached = 50;
  static const _table = 'chat_messages';

  /// Sync load from SharedPreferences cache (instant, for initial display).
  List<ChatMessage> loadCachedMessages() {
    final raw = _storage.getString(_key);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return ChatMessage(
        id: map['id'] as String?,
        role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        text: map['text'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
    }).toList();
  }

  /// Fetch messages from Supabase with cursor pagination and 48h filter.
  /// Throws on network error so the caller can surface the error to the user.
  Future<List<ChatMessage>> fetchMessages({
    int limit = 20,
    DateTime? before,
  }) async {
    final cutoff =
        DateTime.now().subtract(const Duration(hours: 48)).toUtc();

    var query = _client
        .from(_table)
        .select()
        .gt('created_at', cutoff.toIso8601String());

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    final messages = (response as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();

    // Cache first page (most recent messages) only
    if (before == null) {
      await _cacheMessages(messages);
    }

    return messages;
  }

  /// Delete all user messages from server, then clear local cache.
  /// Throws on network error so caller can show error state.
  Future<void> deleteAllMessages() async {
    await _client.from(_table).delete().neq('id', '');
    await _storage.remove(_key);
  }

  /// Save messages to local cache (SharedPreferences).
  Future<void> saveMessages(List<ChatMessage> messages) async {
    final trimmed = messages.length > _maxCached
        ? messages.sublist(messages.length - _maxCached)
        : messages;

    final list = trimmed
        .map((m) => {
              'id': m.id,
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'text': m.text,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList();

    await _storage.setString(_key, jsonEncode(list));
  }

  /// Clear local cache only.
  Future<void> clearCache() async {
    await _storage.remove(_key);
  }

  ChatMessage _fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String?,
      role: row['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      text: row['text'] as String,
      timestamp: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> _cacheMessages(List<ChatMessage> messages) async {
    await saveMessages(messages);
  }

  /// Send a message to the chat Edge Function and return the raw response.
  Future<FunctionResponse> sendChatMessage({
    required String message,
    String? contextSource,
    String? contextPayload,
  }) async {
    return await _client.functions.invoke(
      'chat',
      body: {
        'message': message,
        'context_source': contextSource,
        'context_payload': contextPayload,
      },
    );
  }
}

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(
    ref.watch(localStorageProvider),
    ref.watch(supabaseClientProvider),
  );
}
