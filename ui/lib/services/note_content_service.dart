import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class NoteContentService {
  final int port;
  final http.Client _httpClient;
  final Duration _requestTimeout;

  NoteContentService({
    this.port = 8000,
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _requestTimeout = requestTimeout;

  Future<String> fetchNotes() async {
    try {
      final uri = Uri.http('localhost:$port', '/notes');
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['content'] as String? ?? '';
      }
      return '';
    } on TimeoutException {
      return '';
    }
  }

  Future<bool> saveNotes(String content) async {
    try {
      final uri = Uri.http('localhost:$port', '/notes');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': content}),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    }
  }
}
