import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../application/chat_provider.dart';
import '../domain/chat_message.dart';
import 'widgets/message_bubble.dart';
import 'widgets/suggested_prompts.dart';
import 'widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _initialPromptSent = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialPromptSent) {
          _initialPromptSent = true;
          ref.read(chatNotifierProvider.notifier).sendMessage(
                widget.initialPrompt!,
                contextPayload: widget.initialPrompt,
              );
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels <= position.minScrollExtent + 200) {
      final state = ref.read(chatNotifierProvider);
      if (!state.isLoadingMore && state.hasMore) {
        ref.read(chatNotifierProvider.notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatNotifierProvider);

    // Auto-scroll when new messages arrive at the end (not for pagination prepend)
    ref.listen(chatNotifierProvider, (prev, next) {
      if (prev == null) return;
      final isNewAtEnd = next.messages.length > prev.messages.length &&
          (prev.messages.isEmpty ||
              next.messages.last.timestamp
                  .isAfter(prev.messages.last.timestamp));
      if (isNewAtEnd || prev.streamingText != next.streamingText) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 20, color: AppColors.primary),
            ),
            gapW12,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Tutor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  state.isLoading ? 'Typing...' : 'Online',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: state.isLoading ? AppColors.warning : const Color(0xFF00E676),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Daily limit badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: state.isLimitReached
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.dailyRemaining}/${state.dailyLimit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: state.isLimitReached ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
          ),
          if (state.messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.textTertiary),
              onPressed: () => ref.read(chatNotifierProvider.notifier).clearHistory(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        children: [
          // Error banner
          if (state.error != null)
            _ErrorBanner(
              message: state.error!,
              onDismiss: () => ref.read(chatNotifierProvider.notifier).clearError(),
              onRetry: state.messages.isNotEmpty
                  ? () {
                      final lastUserMsg = state.messages
                          .lastWhere((m) => m.role == MessageRole.user);
                      ref.read(chatNotifierProvider.notifier).sendMessage(lastUserMsg.text);
                    }
                  : null,
            ),
          // Messages
          Expanded(
            child: state.isEmpty && !state.isLoading
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SuggestedPrompts(
                      onPromptSelected: _sendMessage,
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: (state.isLoadingMore ? 1 : 0) +
                        state.messages.length +
                        (state.isStreaming ? 1 : 0) +
                        (state.isLoading && !state.isStreaming ? 1 : 0),
                    separatorBuilder: (_, __) => gapH12,
                    itemBuilder: (context, index) {
                      // Loading indicator at top for pagination
                      if (state.isLoadingMore && index == 0) {
                        return const _PaginationLoader();
                      }
                      final msgIndex =
                          index - (state.isLoadingMore ? 1 : 0);
                      if (msgIndex < state.messages.length) {
                        return MessageBubble(
                            message: state.messages[msgIndex]);
                      }
                      // Streaming partial message
                      if (state.isStreaming) {
                        return MessageBubble(
                          message: ChatMessage(
                            role: MessageRole.assistant,
                            text: state.streamingText!,
                            timestamp: DateTime.now(),
                          ),
                        );
                      }
                      // Typing indicator (before streaming starts)
                      return const TypingIndicator();
                    },
                  ),
          ),
          // Limit reached banner
          if (state.isLimitReached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                  gapW8,
                  Expanded(
                    child: Text(
                      'Дневной лимит исчерпан (${state.dailyLimit} сообщений). Попробуй завтра!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Input bar
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: state.isLoading || state.isLimitReached,
            onSend: () => _sendMessage(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          gapW8,
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Напиши сообщение...',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          gapW8,
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLoading ? AppColors.surfaceDim : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: isLoading ? AppColors.textHint : Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationLoader extends StatelessWidget {
  const _PaginationLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
