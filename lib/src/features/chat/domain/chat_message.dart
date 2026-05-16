enum MessageRole { user, assistant }

enum ChatContextSource { home, grammar, practice }

class ChatContext {
  const ChatContext({
    required this.source,
    required this.payload,
  });

  final ChatContextSource source;
  final String payload;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.id,
    this.context,
  });

  final String? id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final ChatContext? context;
}
