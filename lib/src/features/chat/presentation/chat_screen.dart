import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/chat_provider.dart';
import '../domain/chat_message.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/error_banner.dart';
import 'widgets/limit_banner.dart';
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
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialPromptSent) {
          _initialPromptSent = true;
          ref
              .read(chatNotifierProvider.notifier)
              .sendMessage(
                widget.initialPrompt!,
                contextPayload: widget.initialPrompt,
              );
        }
      });
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

    // Auto-scroll when new messages or streaming text arrives
    ref.listen(chatNotifierProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.streamingText != next.streamingText) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
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
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: AppColors.primary,
              ),
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
                    color: state.isLoading
                        ? AppColors.warning
                        : const Color(0xFF00E676),
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
                  color: state.isLimitReached
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
            ),
          ),
          if (state.messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.textTertiary),
              onPressed: () =>
                  ref.read(chatNotifierProvider.notifier).clearHistory(),
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
            ChatErrorBanner(
              message: state.error!,
              onDismiss: () =>
                  ref.read(chatNotifierProvider.notifier).clearError(),
              onRetry: state.messages.isNotEmpty
                  ? () {
                      final lastUserMsg = state.messages.lastWhere(
                        (m) => m.role == MessageRole.user,
                      );
                      ref
                          .read(chatNotifierProvider.notifier)
                          .sendMessage(lastUserMsg.text);
                    }
                  : null,
            ),
          // Messages
          Expanded(
            child: state.isEmpty && !state.isLoading
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SuggestedPrompts(onPromptSelected: _sendMessage),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount:
                        state.messages.length +
                        (state.isStreaming ? 1 : 0) +
                        (state.isLoading && !state.isStreaming ? 1 : 0),
                    separatorBuilder: (_, __) => gapH12,
                    itemBuilder: (context, index) {
                      if (index < state.messages.length) {
                        return MessageBubble(message: state.messages[index]);
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
            LimitBanner(dailyLimit: state.dailyLimit),
          // Input bar
          ChatInputBar(
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
