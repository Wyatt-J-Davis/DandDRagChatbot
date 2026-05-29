import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/note_content_service.dart';

void main() {
  group('NoteContentService', () {
    test('fetchNotes returns content from /notes endpoint', () async {
      final client = MockClient((_) async => http.Response(
            '{"content": "Session 1: dragons attacked."}',
            200,
          ));
      final service = NoteContentService(port: 9999, httpClient: client);

      final result = await service.fetchNotes();

      expect(result, 'Session 1: dragons attacked.');
    });

    test('fetchNotes returns empty string on non-200 response', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final service = NoteContentService(port: 9999, httpClient: client);

      final result = await service.fetchNotes();

      expect(result, '');
    });

    test('fetchNotes returns empty string when content key is absent', () async {
      final client = MockClient(
          (_) async => http.Response('{"other": "value"}', 200));
      final service = NoteContentService(port: 9999, httpClient: client);

      final result = await service.fetchNotes();

      expect(result, '');
    });

    test('fetchNotes GETs /notes on the configured port', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"content": ""}', 200);
      });
      final service = NoteContentService(port: 9999, httpClient: client);

      await service.fetchNotes();

      expect(captured, isNotNull);
      expect(captured!.method, 'GET');
      expect(captured!.url.port, 9999);
      expect(captured!.url.path, '/notes');
    });
  });

  group('saveNotes', () {
    test('POSTs content to /notes and returns true on 200', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = NoteContentService(port: 9999, httpClient: client);

      final result = await service.saveNotes('My campaign notes.');

      expect(result, isTrue);
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/notes');
      expect(captured!.url.port, 9999);
    });

    test('sends content in request body', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = NoteContentService(port: 9999, httpClient: client);

      await service.saveNotes('Session notes here.');

      expect(captured!.body, contains('Session notes here.'));
    });

    test('returns false on non-200 response', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final service = NoteContentService(port: 9999, httpClient: client);

      final result = await service.saveNotes('content');

      expect(result, isFalse);
    });
  });
}
