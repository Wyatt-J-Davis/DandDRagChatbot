import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';

http.StreamedResponse _sseResponse(List<String> jsonPayloads) {
  final body = jsonPayloads.map((j) => 'data: $j\n\n').join();
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

void main() {
  group('ChatService', () {
    test('emits ChatProgressEvent for each non-done SSE line', () async {
      final client = MockClient.streaming((request, _) async => _sseResponse([
            '{"done":false,"progress":10,"message":"Retrieving relevant notes…"}',
            '{"done":false,"progress":50,"message":"Generating response…"}',
            '{"done":true,"answer":"The answer","sources":[]}',
          ]));

      final service = ChatService(port: 9999, httpClient: client);
      final events = await service
          .chat(question: 'q', model: 'm', temperature: 0.5)
          .toList();

      expect(events.length, 3);
      expect(events[0], isA<ChatProgressEvent>());
      expect((events[0] as ChatProgressEvent).message,
          'Retrieving relevant notes…');
      expect(events[1], isA<ChatProgressEvent>());
      expect((events[1] as ChatProgressEvent).message,
          'Generating response…');
      expect(events[2], isA<ChatAnswerEvent>());
    });

    test('emits ChatAnswerEvent with answer and sources on done event',
        () async {
      final client = MockClient.streaming((request, _) async => _sseResponse([
            '{"done":true,"answer":"42","sources":["source A","source B"]}',
          ]));

      final service = ChatService(port: 9999, httpClient: client);
      final events = await service
          .chat(question: 'q', model: 'm', temperature: 0.5)
          .toList();

      expect(events, [isA<ChatAnswerEvent>()]);
      final answer = events[0] as ChatAnswerEvent;
      expect(answer.answer, '42');
      expect(answer.sources, ['source A', 'source B']);
    });

    test('emits ChatErrorEvent on error done event', () async {
      final client = MockClient.streaming((request, _) async => _sseResponse([
            '{"done":true,"error":true,"message":"Model not found"}',
          ]));

      final service = ChatService(port: 9999, httpClient: client);
      final events = await service
          .chat(question: 'q', model: 'm', temperature: 0.5)
          .toList();

      expect(events, [isA<ChatErrorEvent>()]);
      expect((events[0] as ChatErrorEvent).message, 'Model not found');
    });

    test('sends POST to /chat with correct body', () async {
      http.BaseRequest? captured;

      final client = MockClient.streaming((request, _) async {
        captured = request;
        return _sseResponse(['{"done":true,"answer":"ok","sources":[]}']);
      });

      final service = ChatService(port: 9999, httpClient: client);
      await service
          .chat(question: 'What happened?', model: 'llama3', temperature: 0.7)
          .toList();

      expect(captured, isNotNull);
      expect(captured!.url.path, '/chat');
      expect(captured!.method, 'POST');
      final body =
          jsonDecode((captured as http.Request).body) as Map<String, dynamic>;
      expect(body['question'], 'What happened?');
      expect(body['model'], 'llama3');
      expect(body['temperature'], closeTo(0.7, 0.001));
    });

    test('hits the configured port', () async {
      int? capturedPort;

      final client = MockClient.streaming((request, _) async {
        capturedPort = request.url.port;
        return _sseResponse(['{"done":true,"answer":"ok","sources":[]}']);
      });

      final service = ChatService(port: 7777, httpClient: client);
      await service
          .chat(question: 'q', model: 'm', temperature: 0.5)
          .toList();

      expect(capturedPort, 7777);
    });

    test('ignores SSE lines that do not start with data:', () async {
      const body =
          ': keep-alive\n\ndata: {"done":true,"answer":"ok","sources":[]}\n\n';
      final client = MockClient.streaming((_, __) async =>
          http.StreamedResponse(Stream.value(utf8.encode(body)), 200,
              headers: {'content-type': 'text/event-stream'}));

      final service = ChatService(port: 9999, httpClient: client);
      final events = await service
          .chat(question: 'q', model: 'm', temperature: 0.5)
          .toList();

      expect(events, [isA<ChatAnswerEvent>()]);
    });
  });
}
