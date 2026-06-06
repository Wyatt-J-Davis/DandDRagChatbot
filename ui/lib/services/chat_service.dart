import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum ChatSender { user, assistant }

class ChatSource {
  final String content;
  final String? date;
  const ChatSource({required this.content, this.date});

  Map<String, dynamic> toJson() => {
        'content': content,
        if (date != null) 'date': date,
      };

  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
        content: json['content']?.toString() ?? '',
        date: json['date']?.toString(),
      );
}

class ChatMessage {
  final ChatSender sender;
  final String text;
  final List<ChatSource> sources;
  const ChatMessage({
    required this.sender,
    required this.text,
    this.sources = const [],
  });

  Map<String, dynamic> toJson() => {
        'sender': sender.name,
        'text': text,
        'sources': sources.map((s) => s.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        sender: ChatSender.values.firstWhere(
          (s) => s.name == json['sender'],
          orElse: () => ChatSender.assistant,
        ),
        text: json['text']?.toString() ?? '',
        sources: (json['sources'] as List<dynamic>?)
                ?.map((e) => ChatSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

sealed class ChatEvent {}

final class ChatProgressEvent extends ChatEvent {
  final String message;
  ChatProgressEvent({required this.message});
}

final class ChatAnswerEvent extends ChatEvent {
  final String answer;
  final List<ChatSource> sources;
  ChatAnswerEvent({required this.answer, required this.sources});
}

final class ChatErrorEvent extends ChatEvent {
  final String message;
  ChatErrorEvent({required this.message});
}

class ChatService {
  final int port;
  final http.Client _httpClient;
  final Duration _connectTimeout;
  final Duration _streamIdleTimeout;

  ChatService({
    this.port = 8000,
    http.Client? httpClient,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration streamIdleTimeout = const Duration(seconds: 240),
  })  : _httpClient = httpClient ?? http.Client(),
        _connectTimeout = connectTimeout,
        _streamIdleTimeout = streamIdleTimeout;

  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    final uri = Uri.http('localhost:$port', '/chat');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'question': question,
        'model': model,
        'temperature': temperature,
      });

    try {
      final response =
          await _httpClient.send(request).timeout(_connectTimeout);
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(_streamIdleTimeout);

      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final payload = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        if (payload['done'] == true) {
          if (payload['error'] == true) {
            yield ChatErrorEvent(
                message: payload['message']?.toString() ?? 'Unknown error');
          } else {
            yield ChatAnswerEvent(
              answer: payload['answer']?.toString() ?? '',
              sources: (payload['sources'] as List<dynamic>?)
                      ?.map((e) {
                        final map = e as Map<String, dynamic>;
                        final rawDate = map['date']?.toString();
                        return ChatSource(
                          content: map['content']?.toString() ?? '',
                          date: (rawDate == null || rawDate == 'Unknown')
                              ? null
                              : rawDate,
                        );
                      })
                      .toList() ??
                  [],
            );
          }
          return;
        }
        yield ChatProgressEvent(message: payload['message']?.toString() ?? '');
      }
    } on TimeoutException {
      yield ChatErrorEvent(message: 'Request timed out');
    }
  }
}
