import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/party_service.dart';

void main() {
  group('PartyService', () {
    test('fetchPartyMembers returns list of names from response', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"party_members": [{"name": "Aria", "note_taker": true}, {"name": "Borin", "note_taker": false}]}',
          200,
        ),
      );
      final service = PartyService(port: 9999, httpClient: client);
      expect(await service.fetchPartyMembers(), ['Aria', 'Borin']);
    });

    test('fetchPartyMembers returns empty list when party_members is empty', () async {
      final client = MockClient(
        (_) async => http.Response('{"party_members": []}', 200),
      );
      final service = PartyService(port: 9999, httpClient: client);
      expect(await service.fetchPartyMembers(), isEmpty);
    });

    test('fetchPartyMembers throws on non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );
      final service = PartyService(port: 9999, httpClient: client);
      expect(() => service.fetchPartyMembers(), throwsException);
    });

    test('fetchPartyMembers hits /party path with correct port', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"party_members": []}', 200);
      });
      final service = PartyService(port: 8765, httpClient: client);
      await service.fetchPartyMembers();
      expect(capturedUri?.path, '/party');
      expect(capturedUri?.port, 8765);
    });
  });
}
