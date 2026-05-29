import 'dart:convert';

import 'package:http/http.dart' as http;

class PartyService {
  final int port;
  final http.Client _httpClient;

  PartyService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<List<String>> fetchPartyMembers() async {
    final uri = Uri.http('localhost:$port', '/party');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch party: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final members = body['party_members'] as List<dynamic>;
    return members
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }
}
