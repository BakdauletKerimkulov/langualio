import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/logger.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

part 'chat_provider.g.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.streamingText,
    this.dailyLimit = 20,
    this.dailyRemaining = 20,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? streamingText;
  final int dailyLimit;
  final int dailyRemaining;

  bool get isEmpty => messages.isEmpty;
  bool get isStreaming => streamingText != null;
  bool get isLimitReached => dailyRemaining <= 0;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    String? streamingText,
    int? dailyLimit,
    int? dailyRemaining,
    bool clearError = false,
    bool clearStreaming = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      streamingText:
          clearStreaming ? null : (streamingText ?? this.streamingText),
      dailyLimit: dailyLimit ?? this.dailyLimit,
      dailyRemaining: dailyRemaining ?? this.dailyRemaining,
    );
  }
}

@riverpod
class ChatNotifier extends _$ChatNotifier {
  static const _pageSize = 20;

  @override
  ChatState build() {
    final cached = _repository.loadCachedMessages();
    if (cached.isNotEmpty) {
      _refreshFromServer();
      return ChatState(messages: cached);
    }
    _refreshFromServer();
    return const ChatState();
  }

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  Future<void> _refreshFromServer() async {
    final messages = await _repository.fetchMessages(limit: _pageSize);
    if (messages.isNotEmpty) {
      state = state.copyWith(
        messages: messages,
        hasMore: messages.length >= _pageSize,
      );
    } else if (state.messages.isEmpty) {
      state = state.copyWith(hasMore: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    if (state.messages.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);

    final oldest = state.messages.first.timestamp;
    final older = await _repository.fetchMessages(
      limit: _pageSize,
      before: oldest,
    );

    state = state.copyWith(
      messages: [...older, ...state.messages],
      isLoadingMore: false,
      hasMore: older.length >= _pageSize,
    );
  }

  Future<void> sendMessage(
    String text, {
    String? contextSource,
    String? contextPayload,
  }) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      role: MessageRole.user,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    await _repository.saveMessages(state.messages);

    try {
      final response = await _repository.sendChatMessage(
        message: text.trim(),
        contextSource: contextSource,
        contextPayload: contextPayload,
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      log(
        'Response status=${response.status}, data=$data',
        name: 'ChatProvider',
      );

      if (response.status == 429) {
        final limit = data['daily_limit'] as int? ?? state.dailyLimit;
        state = state.copyWith(
          isLoading: false,
          error: 'Дневной лимит исчерпан ($limit сообщений). Попробуй завтра!',
          dailyRemaining: 0,
        );
        return;
      }

      if (response.status != 200) {
        log('Edge function error: ${response.status}', name: 'ChatProvider');
        state = state.copyWith(
          isLoading: false,
          error: 'Ошибка AI-сервиса. Попробуй позже.',
        );
        return;
      }

      final responseText = data['text'] as String? ?? '';
      final limit = data['daily_limit'] as int? ?? state.dailyLimit;
      final remaining = data['daily_remaining'] as int? ?? state.dailyRemaining;

      if (responseText.isEmpty) {
        log(
          'Empty response text from AI. Full data: $data',
          name: 'ChatProvider',
        );
        state = state.copyWith(
          isLoading: false,
          error: 'AI вернул пустой ответ. Попробуй ещё раз.',
          dailyLimit: limit,
          dailyRemaining: remaining,
        );
        return;
      }

      state = state.copyWith(
        dailyLimit: limit,
        dailyRemaining: remaining,
      );

      _addAssistantMessage(responseText);
    } catch (e) {
      log('Send error: $e', name: 'ChatProvider');
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось отправить сообщение. Проверь интернет.',
        clearStreaming: true,
      );
    }
  }

  void _addAssistantMessage(String text) {
    final assistantMessage = ChatMessage(
      role: MessageRole.assistant,
      text: text,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
      isLoading: false,
      clearStreaming: true,
    );

    _repository.saveMessages(state.messages);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> clearHistory() async {
    try {
      await _repository.deleteAllMessages();
      state = ChatState(
        dailyLimit: state.dailyLimit,
        dailyRemaining: state.dailyRemaining,
      );
    } catch (e) {
      log('clearHistory error: $e', name: 'ChatProvider');
      state = state.copyWith(
        error: 'Не удалось очистить историю. Проверь интернет.',
      );
    }
  }
}
