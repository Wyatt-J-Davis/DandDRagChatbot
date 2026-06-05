import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class NoteExportService {
  final int port;
  final http.Client _httpClient;
  final Duration _requestTimeout;

  NoteExportService({
    this.port = 8000,
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _requestTimeout = requestTimeout;

  Future<Uint8List?> fetchTxtBytes() async {
    try {
      final uri = Uri.http('localhost:$port', '/notes/export/txt');
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<Uint8List?> fetchDocxBytes() async {
    try {
      final uri = Uri.http('localhost:$port', '/notes/export/docx');
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } on TimeoutException {
      return null;
    }
  }
}
