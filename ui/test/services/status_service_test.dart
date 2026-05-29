import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/status_service.dart';

void main() {
  group('StatusService', () {
    test('fetchHasNotes returns true when backend reports notes present', () async {
      final client = MockClient(
        (_) async => http.Response('{"has_notes": true}', 200),
      );
      final service = StatusService(port: 9999, httpClient: client);
      expect(await service.fetchHasNotes(), isTrue);
    });

    test('fetchHasNotes returns false when backend reports no notes', () async {
      final client = MockClient(
        (_) async => http.Response('{"has_notes": false}', 200),
      );
      final service = StatusService(port: 9999, httpClient: client);
      expect(await service.fetchHasNotes(), isFalse);
    });

    test('fetchHasNotes throws on non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );
      final service = StatusService(port: 9999, httpClient: client);
      expect(() => service.fetchHasNotes(), throwsException);
    });

    test('fetchHasNotes hits /status path', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"has_notes": false}', 200);
      });
      final service = StatusService(port: 8765, httpClient: client);
      await service.fetchHasNotes();
      expect(capturedUri?.path, '/status');
      expect(capturedUri?.port, 8765);
    });
  });
}
