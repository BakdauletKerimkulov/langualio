import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langualio/src/features/chat/application/chat_provider.dart';
import 'package:langualio/src/features/chat/data/chat_repository.dart';
import 'package:langualio/src/features/chat/domain/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ChatNotifier.sendMessage', () {
    test('parses JSON response → correct dailyLimit, dailyRemaining, and assistant text', () async {
      final fakeRepo = _FakeChatRepository(
        sendResult: FunctionResponse(
          status: 200,
          data: {
            'text': 'Hello! How can I help you learn English?',
            'daily_limit': 20,
            'daily_remaining': 17,
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.sendMessage('Hello');

      final state = container.read(chatNotifierProvider);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.dailyLimit, 20);
      expect(state.dailyRemaining, 17);
      expect(state.messages, hasLength(2)); // user + assistant
      expect(state.messages.last.role, MessageRole.assistant);
      expect(state.messages.last.text, 'Hello! How can I help you learn English?');
    });

    test('429 response sets isLimitReached with error message', () async {
      final fakeRepo = _FakeChatRepository(
        sendResult: FunctionResponse(
          status: 429,
          data: {
            'error': 'Daily message limit reached',
            'daily_limit': 20,
            'daily_remaining': 0,
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.sendMessage('Hello');

      final state = container.read(chatNotifierProvider);
      expect(state.isLoading, false);
      expect(state.isLimitReached, true);
      expect(state.dailyRemaining, 0);
      expect(state.error, isNotNull);
      expect(state.error, contains('лимит'));
    });

    test('502 response sets error message', () async {
      final fakeRepo = _FakeChatRepository(
        sendResult: FunctionResponse(
          status: 502,
          data: {'error': 'AI service error'},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.sendMessage('Hello');

      final state = container.read(chatNotifierProvider);
      expect(state.isLoading, false);
      expect(state.error, isNotNull);
      expect(state.error, contains('Ошибка'));
    });

    test('network error sets error with internet message', () async {
      final fakeRepo = _FakeChatRepository(sendThrows: true);

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.sendMessage('Hello');

      final state = container.read(chatNotifierProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('интернет'));
    });
  });

  group('ChatState', () {
    test('default constructor has correct field defaults', () {
      const state = ChatState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
      expect(state.isLoadingMore, false);
      expect(state.hasMore, true);
      expect(state.error, isNull);
      expect(state.streamingText, isNull);
      expect(state.dailyLimit, 20);
      expect(state.dailyRemaining, 20);
    });

    test('isLimitReached returns true when dailyRemaining is 0', () {
      const state = ChatState(dailyRemaining: 0);
      expect(state.isLimitReached, true);
    });

    test('isLimitReached returns false when dailyRemaining > 0', () {
      const state = ChatState(dailyRemaining: 5);
      expect(state.isLimitReached, false);
    });

    test('copyWith clearError sets error to null', () {
      const state = ChatState(error: 'Something went wrong');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearStreaming sets streamingText to null', () {
      const state = ChatState(streamingText: 'partial response');
      final cleared = state.copyWith(clearStreaming: true);
      expect(cleared.streamingText, isNull);
    });

    test('copyWith preserves fields not explicitly changed', () {
      const state = ChatState(
        dailyLimit: 15,
        dailyRemaining: 10,
        isLoading: true,
      );
      final updated = state.copyWith(isLoading: false);
      expect(updated.isLoading, false);
      expect(updated.dailyLimit, 15);
      expect(updated.dailyRemaining, 10);
    });
  });
}

// ── Test doubles ──

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.sendResult, this.sendThrows = false});

  final FunctionResponse? sendResult;
  final bool sendThrows;

  @override
  List<ChatMessage> loadCachedMessages() => [];

  @override
  Future<List<ChatMessage>> fetchMessages({int limit = 20, DateTime? before}) async => [];

  @override
  Future<void> deleteAllMessages() async {}

  @override
  Future<void> saveMessages(List<ChatMessage> messages) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<FunctionResponse> sendChatMessage({
    required String message,
    String? contextSource,
    String? contextPayload,
  }) async {
    if (sendThrows) {
      throw Exception('Network error');
    }
    return sendResult!;
  }
}
