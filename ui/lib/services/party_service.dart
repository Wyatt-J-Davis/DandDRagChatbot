import 'dart:convert';

import 'package:http/http.dart' as http;

class PartyService {
  final int port;
  final http.Client _httpClient;

  PartyService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<({List<String> members, String? noteTaker})> fetchPartyMembers() async {
    final uri = Uri.http('localhost:$port', '/party');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch party: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = body['party_members'] as List<dynamic>;
    final members = raw
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final noteTakerEntry = raw.cast<Map<String, dynamic>>().where(
      (m) => m['note_taker'] == true && (m['name'] as String).trim().isNotEmpty,
    ).firstOrNull;
    final noteTaker = noteTakerEntry?['name'] as String?;
    return (members: members, noteTaker: noteTaker);
  }

  Future<void> savePartyMembers(List<String> members, String? noteTaker) async {
    final uri = Uri.http('localhost:$port', '/party');
    final body = jsonEncode({
      'party_members': members
          .map((name) => {'name': name, 'note_taker': name == noteTaker})
          .toList(),
    });
    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save party: ${response.statusCode}');
    }
  }
}
