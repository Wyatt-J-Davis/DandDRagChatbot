import 'dart:convert';

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
      final result = await service.fetchPartyMembers();
      expect(result.members, ['Aria', 'Borin']);
    });

    test('fetchPartyMembers returns empty list when party_members is empty', () async {
      final client = MockClient(
        (_) async => http.Response('{"party_members": []}', 200),
      );
      final service = PartyService(port: 9999, httpClient: client);
      final result = await service.fetchPartyMembers();
      expect(result.members, isEmpty);
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

    test('fetchPartyMembers returns note taker name when a member has note_taker true', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"party_members": [{"name": "Aria", "note_taker": false}, {"name": "Borin", "note_taker": true}]}',
          200,
        ),
      );
      final service = PartyService(port: 9999, httpClient: client);
      final result = await service.fetchPartyMembers();
      expect(result.noteTaker, 'Borin');
    });

    test('fetchPartyMembers returns null noteTaker when no member has note_taker true', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"party_members": [{"name": "Aria", "note_taker": false}, {"name": "Borin", "note_taker": false}]}',
          200,
        ),
      );
      final service = PartyService(port: 9999, httpClient: client);
      final result = await service.fetchPartyMembers();
      expect(result.noteTaker, isNull);
    });

    test('fetchPartyMembers returns null noteTaker when party is empty', () async {
      final client = MockClient(
        (_) async => http.Response('{"party_members": []}', 200),
      );
      final service = PartyService(port: 9999, httpClient: client);
      final result = await service.fetchPartyMembers();
      expect(result.noteTaker, isNull);
    });
  });

  group('savePartyMembers', () {
    test('POSTs to /party with correct JSON body', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = PartyService(port: 9999, httpClient: client);
      await service.savePartyMembers(['Aria', 'Borin'], 'Aria');
      expect(captured?.method, 'POST');
      expect(captured?.url.path, '/party');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      final members = body['party_members'] as List<dynamic>;
      expect(members, hasLength(2));
      expect(members[0], {'name': 'Aria', 'note_taker': true});
      expect(members[1], {'name': 'Borin', 'note_taker': false});
    });

    test('sends note_taker false for all members when noteTaker is null', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = PartyService(port: 9999, httpClient: client);
      await service.savePartyMembers(['Aria', 'Borin'], null);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      final members = body['party_members'] as List<dynamic>;
      expect(members[0], {'name': 'Aria', 'note_taker': false});
      expect(members[1], {'name': 'Borin', 'note_taker': false});
    });

    test('sends empty list when members is empty', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = PartyService(port: 9999, httpClient: client);
      await service.savePartyMembers([], null);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['party_members'], isEmpty);
    });

    test('throws on non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('Server Error', 500),
      );
      final service = PartyService(port: 9999, httpClient: client);
      expect(() => service.savePartyMembers(['Aria'], null), throwsException);
    });

    test('uses correct port', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"status": "ok"}', 200);
      });
      final service = PartyService(port: 8765, httpClient: client);
      await service.savePartyMembers(['Aria'], 'Aria');
      expect(capturedUri?.port, 8765);
    });
  });
}
