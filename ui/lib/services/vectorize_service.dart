import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

sealed class VectorizeEvent {}

final class VectorizeProgressEvent extends VectorizeEvent {
  final int progress;
  final String message;

  VectorizeProgressEvent({required this.progress, required this.message});
}

final class VectorizeDoneEvent extends VectorizeEvent {}

final class VectorizeErrorEvent extends VectorizeEvent {
  final String message;

  VectorizeErrorEvent({required this.message});
}

class VectorizeService {
  final int port;
  final http.Client _httpClient;

  VectorizeService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Stream<VectorizeEvent> vectorize(String plainText) async* {
    final uri = Uri.http('localhost:$port', '/notes/vectorize');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'text': plainText});

    final response = await _httpClient.send(request);
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final payload = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      if (payload['done'] == true) {
        if (payload['error'] == true) {
          yield VectorizeErrorEvent(
              message: payload['message']?.toString() ?? 'Unknown error');
        } else {
          yield VectorizeDoneEvent();
        }
        return;
      }
      yield VectorizeProgressEvent(
        progress: (payload['progress'] as num?)?.toInt() ?? 0,
        message: payload['message']?.toString() ?? '',
      );
    }
  }
}
