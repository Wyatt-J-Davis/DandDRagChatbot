import 'dart:convert';

import 'package:http/http.dart' as http;

class ModelService {
  final int port;
  final http.Client _httpClient;

  ModelService({
    this.port = 8000,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<List<String>> fetchModels() async {
    final uri = Uri.http('localhost:$port', '/models');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch models: ${response.statusCode}');
    }
    final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
    return body.cast<String>();
  }
}
