import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class ClaudeApiClient {
  ClaudeApiClient({required this.apiKey});

  final String apiKey;
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-20250514';
  static const _maxTokens = 1024;

  /// Sends a message and returns streaming text chunks via a Stream.
  Stream<String> streamMessage({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async* {
    final body = jsonEncode({
      'model': _model,
      'max_tokens': _maxTokens,
      'stream': true,
      'system': systemPrompt,
      'messages': messages,
    });

    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    });
    request.body = body;

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        log('Claude API error: ${response.statusCode} $errorBody', name: 'ClaudeAPI');
        throw ClaudeApiException(
          statusCode: response.statusCode,
          message: _parseErrorMessage(errorBody),
        );
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6);
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final type = json['type'] as String?;

          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            final text = delta?['text'] as String?;
            if (text != null) yield text;
          }
        } catch (_) {
          // Skip malformed SSE lines
        }
      }
    } finally {
      client.close();
    }
  }

  /// Sends a message and returns the full response (non-streaming).
  Future<String> sendMessage({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamMessage(
      systemPrompt: systemPrompt,
      messages: messages,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  String _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? 'Unknown error';
    } catch (_) {
      return body;
    }
  }
}

class ClaudeApiException implements Exception {
  ClaudeApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  bool get isRateLimit => statusCode == 429;
  bool get isAuth => statusCode == 401;

  @override
  String toString() => 'ClaudeApiException($statusCode): $message';
}
