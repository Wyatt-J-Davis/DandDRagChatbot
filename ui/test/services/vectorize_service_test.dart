import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/vectorize_service.dart';

http.Response _sseResponse(String body) =>
    http.Response(body, 200, headers: {'content-type': 'text/event-stream'});

void main() {
  group('VectorizeService', () {
    test('yields VectorizeProgressEvent from SSE stream', () async {
      final client = MockClient((_) async => _sseResponse(
            'data: {"progress": 30, "message": "Chunking"}\n\n'
            'data: {"done": true}\n\n',
          ));
      final service = VectorizeService(port: 9999, httpClient: client);

      final events = await service.vectorize('hello world').toList();

      expect(events.first, isA<VectorizeProgressEvent>());
      final progress = events.first as VectorizeProgressEvent;
      expect(progress.progress, 30);
      expect(progress.message, 'Chunking');
    });

    test('yields VectorizeDoneEvent when done:true received', () async {
      final client = MockClient((_) async => _sseResponse(
            'data: {"progress": 100, "message": "Done"}\n\n'
            'data: {"done": true}\n\n',
          ));
      final service = VectorizeService(port: 9999, httpClient: client);

      final events = await service.vectorize('text').toList();

      expect(events.last, isA<VectorizeDoneEvent>());
    });

    test('yields VectorizeErrorEvent when error:true received', () async {
      final client = MockClient((_) async => _sseResponse(
            'data: {"done": true, "error": true, "message": "DB unavailable"}\n\n',
          ));
      final service = VectorizeService(port: 9999, httpClient: client);

      final events = await service.vectorize('text').toList();

      expect(events.first, isA<VectorizeErrorEvent>());
      final err = events.first as VectorizeErrorEvent;
      expect(err.message, 'DB unavailable');
    });

    test('POSTs plain text to /notes/vectorize', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return _sseResponse('data: {"done": true}\n\n');
      });
      final service = VectorizeService(port: 9999, httpClient: client);

      await service.vectorize('my plain text').toList();

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/notes/vectorize');
      expect(captured!.body, contains('my plain text'));
    });

    test('skips non-data lines', () async {
      final client = MockClient((_) async => _sseResponse(
            ': keep-alive\n\n'
            'data: {"progress": 50, "message": "Halfway"}\n\n'
            'data: {"done": true}\n\n',
          ));
      final service = VectorizeService(port: 9999, httpClient: client);

      final events = await service.vectorize('text').toList();

      expect(events.length, 2);
      expect(events.first, isA<VectorizeProgressEvent>());
    });

    group('timeout', () {
      test('yields VectorizeErrorEvent when connect hangs past timeout',
          () async {
        final completer = Completer<http.StreamedResponse>();
        final client = MockClient.streaming((_, __) => completer.future);
        final service = VectorizeService(
          port: 9999,
          httpClient: client,
          connectTimeout: const Duration(milliseconds: 20),
        );

        final events = await service.vectorize('text').toList();

        expect(events, [isA<VectorizeErrorEvent>()]);
        expect((events[0] as VectorizeErrorEvent).message, 'Request timed out');
      });

      test('yields VectorizeErrorEvent when stream idles past timeout',
          () async {
        final sc = StreamController<List<int>>();
        final client = MockClient.streaming(
          (_, __) async => http.StreamedResponse(sc.stream, 200),
        );
        final service = VectorizeService(
          port: 9999,
          httpClient: client,
          streamIdleTimeout: const Duration(milliseconds: 20),
        );

        final events = await service.vectorize('text').toList();

        expect(events, [isA<VectorizeErrorEvent>()]);
        expect((events[0] as VectorizeErrorEvent).message, 'Request timed out');
        await sc.close();
      });
    });
  });
}
