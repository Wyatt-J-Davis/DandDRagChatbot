import 'dart:convert';

import 'package:http/http.dart' as http;

class NoteContentService {
  final int port;
  final http.Client _httpClient;

  NoteContentService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<String> fetchNotes() async {
    final uri = Uri.http('localhost:$port', '/notes');
    final response = await _httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['content'] as String? ?? '';
    }
    return '';
  }
}
