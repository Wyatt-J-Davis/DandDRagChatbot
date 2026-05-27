import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';

http.StreamedResponse _sseResponse(List<String> jsonPayloads) {
  final body = jsonPayloads.map((j) => 'data: $j\n\n').join();
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

void main() {
  group('UploadService', () {
    test('emits UploadProgressEvent for each non-done SSE event', () async {
      final client = MockClient.streaming((request, _) async => _sseResponse([
            '{"done":false,"progress":30,"message":"Processing... 30%"}',
            '{"done":false,"progress":60,"message":"Processing... 60%"}',
            '{"done":true,"progress":100}',
          ]));

      final service = UploadService(port: 9999, httpClient: client);
      final events = await service.uploadNotes('/notes.txt').toList();

      expect(events.length, 3);
      expect(events[0], isA<UploadProgressEvent>());
      expect((events[0] as UploadProgressEvent).progress, 30);
      expect((events[0] as UploadProgressEvent).message, 'Processing... 30%');
      expect(events[1], isA<UploadProgressEvent>());
      expect((events[1] as UploadProgressEvent).progress, 60);
      expect(events[2], isA<UploadDoneEvent>());
    });

    test('emits only UploadDoneEvent when only done event arrives', () async {
      final client = MockClient.streaming(
          (request, _) async =>
              _sseResponse(['{"done":true,"progress":100}']));

      final service = UploadService(port: 9999, httpClient: client);
      final events = await service.uploadNotes('/notes.txt').toList();

      expect(events, [isA<UploadDoneEvent>()]);
    });

    test('emits UploadErrorEvent when SSE error event arrives', () async {
      final client = MockClient.streaming(
          (request, _) async => _sseResponse([
                '{"done":true,"error":true,"message":"File not found"}',
              ]));

      final service = UploadService(port: 9999, httpClient: client);
      final events = await service.uploadNotes('/notes.txt').toList();

      expect(events, [isA<UploadErrorEvent>()]);
      expect((events[0] as UploadErrorEvent).message, 'File not found');
    });

    test('sends POST request to /upload-notes with correct file_path body',
        () async {
      http.BaseRequest? captured;

      final client = MockClient.streaming((request, _) async {
        captured = request;
        return _sseResponse(['{"done":true,"progress":100}']);
      });

      final service = UploadService(port: 9999, httpClient: client);
      await service.uploadNotes('/my/campaign.txt').toList();

      expect(captured, isNotNull);
      expect(captured!.url.path, '/upload-notes');
      expect(captured!.method, 'POST');
      final body =
          jsonDecode((captured as http.Request).body) as Map<String, dynamic>;
      expect(body['file_path'], '/my/campaign.txt');
    });

    test('hits the configured port', () async {
      int? capturedPort;

      final client = MockClient.streaming((request, _) async {
        capturedPort = request.url.port;
        return _sseResponse(['{"done":true,"progress":100}']);
      });

      final service = UploadService(port: 7777, httpClient: client);
      await service.uploadNotes('/notes.txt').toList();

      expect(capturedPort, 7777);
    });

    test('ignores SSE lines that do not start with data:', () async {
      const body =
          ': keep-alive\n\ndata: {"done":true,"progress":100}\n\n';
      final client = MockClient.streaming((_, __) async =>
          http.StreamedResponse(
              Stream.value(utf8.encode(body)), 200,
              headers: {'content-type': 'text/event-stream'}));

      final service = UploadService(port: 9999, httpClient: client);
      final events = await service.uploadNotes('/notes.txt').toList();

      expect(events, [isA<UploadDoneEvent>()]);
    });
  });
}
