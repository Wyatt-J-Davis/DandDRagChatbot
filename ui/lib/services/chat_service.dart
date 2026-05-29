import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum ChatSender { user, assistant }

class ChatSource {
  final String content;
  final String? date;
  const ChatSource({required this.content, this.date});
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

  ChatService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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

    final response = await _httpClient.send(request);
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

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
                        date: (rawDate == null || rawDate == 'Unknown') ? null : rawDate,
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
  }
}
