import 'dart:convert';

import 'package:http/http.dart' as http;

class StatusService {
  final int port;
  final http.Client _httpClient;

  StatusService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<bool> fetchHasNotes() async {
    final uri = Uri.http('localhost:$port', '/status');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch status: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['has_notes'] as bool;
  }
}
