import 'dart:typed_data';

import 'package:http/http.dart' as http;

class NoteExportService {
  final int port;
  final http.Client _httpClient;

  NoteExportService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<Uint8List?> fetchTxtBytes() async {
    final uri = Uri.http('localhost:$port', '/notes/export/txt');
    final response = await _httpClient.get(uri);
    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }

  Future<Uint8List?> fetchDocxBytes() async {
    final uri = Uri.http('localhost:$port', '/notes/export/docx');
    final response = await _httpClient.get(uri);
    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }
}
