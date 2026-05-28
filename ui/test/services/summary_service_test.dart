import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';

http.StreamedResponse _sseResponse(List<String> jsonPayloads) {
  final body = jsonPayloads.map((j) => 'data: $j\n\n').join();
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

void main() {
  group('SummaryService', () {
    test('emits SummaryProgressEvent for each non-done SSE line', () async {
      final client =
          MockClient.streaming((request, _) async => _sseResponse([
                '{"done":false,"progress":10,"message":"Summarizing section 1 of 3..."}',
                '{"done":false,"progress":60,"message":"Combining summaries (pass 1)..."}',
                '{"done":true,"progress":100}',
              ]));

      final service = SummaryService(port: 9999, httpClient: client);
      final events = await service
          .generate(model: 'llama3', partyMembers: ['Alice', 'Bob'])
          .toList();

      expect(events.length, 3);
      expect(events[0], isA<SummaryProgressEvent>());
      expect((events[0] as SummaryProgressEvent).message,
          'Summarizing section 1 of 3...');
      expect((events[0] as SummaryProgressEvent).progress, 10);
      expect(events[1], isA<SummaryProgressEvent>());
      expect((events[1] as SummaryProgressEvent).message,
          'Combining summaries (pass 1)...');
      expect(events[2], isA<SummaryDoneEvent>());
    });

    test('emits SummaryDoneEvent on done event without error', () async {
      final client =
          MockClient.streaming((request, _) async => _sseResponse([
                '{"done":true,"progress":100}',
              ]));

      final service = SummaryService(port: 9999, httpClient: client);
      final events = await service
          .generate(model: 'llama3', partyMembers: [])
          .toList();

      expect(events, [isA<SummaryDoneEvent>()]);
    });

    test('emits SummaryErrorEvent on error done event', () async {
      final client =
          MockClient.streaming((request, _) async => _sseResponse([
                '{"done":true,"error":true,"message":"Raw notes not found"}',
              ]));

      final service = SummaryService(port: 9999, httpClient: client);
      final events = await service
          .generate(model: 'llama3', partyMembers: [])
          .toList();

      expect(events, [isA<SummaryErrorEvent>()]);
      expect((events[0] as SummaryErrorEvent).message, 'Raw notes not found');
    });

    test('sends POST to /summary/generate with correct body', () async {
      http.BaseRequest? captured;

      final client = MockClient.streaming((request, _) async {
        captured = request;
        return _sseResponse(['{"done":true,"progress":100}']);
      });

      final service = SummaryService(port: 9999, httpClient: client);
      await service
          .generate(model: 'llama3', partyMembers: ['Alice', 'Bob'])
          .toList();

      expect(captured, isNotNull);
      expect(captured!.url.path, '/summary/generate');
      expect(captured!.method, 'POST');
      final body =
          jsonDecode((captured as http.Request).body) as Map<String, dynamic>;
      expect(body['model'], 'llama3');
      expect(body['party_members'], ['Alice', 'Bob']);
    });

    test('hits the configured port', () async {
      int? capturedPort;

      final client = MockClient.streaming((request, _) async {
        capturedPort = request.url.port;
        return _sseResponse(['{"done":true,"progress":100}']);
      });

      final service = SummaryService(port: 7777, httpClient: client);
      await service.generate(model: 'm', partyMembers: []).toList();

      expect(capturedPort, 7777);
    });

    test('fetchSummary returns summary text from GET /summary', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/summary');
        expect(request.method, 'GET');
        return http.Response(
            jsonEncode({'summary': 'The campaign summary.', 'model': 'llama3'}),
            200);
      });

      final service = SummaryService(port: 9999, httpClient: client);
      final result = await service.fetchSummary();

      expect(result, 'The campaign summary.');
    });

    test('fetchSummary returns null when status is not 200', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = SummaryService(port: 9999, httpClient: client);
      final result = await service.fetchSummary();

      expect(result, isNull);
    });
  });
}
