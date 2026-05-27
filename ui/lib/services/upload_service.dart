import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

sealed class UploadEvent {}

final class UploadProgressEvent extends UploadEvent {
  final int progress;
  final String message;

  UploadProgressEvent({required this.progress, required this.message});
}

final class UploadDoneEvent extends UploadEvent {}

final class UploadErrorEvent extends UploadEvent {
  final String message;

  UploadErrorEvent({required this.message});
}

class UploadService {
  final int port;
  final http.Client _httpClient;

  UploadService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Stream<UploadEvent> uploadNotes(String filePath) async* {
    final uri = Uri.http('localhost:$port', '/upload-notes');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'file_path': filePath});

    final response = await _httpClient.send(request);
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final payload = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      if (payload['done'] == true) {
        if (payload['error'] == true) {
          yield UploadErrorEvent(
              message: payload['message']?.toString() ?? 'Unknown error');
        } else {
          yield UploadDoneEvent();
        }
        return;
      }
      yield UploadProgressEvent(
        progress: (payload['progress'] as num?)?.toInt() ?? 0,
        message: payload['message']?.toString() ?? '',
      );
    }
  }
}
