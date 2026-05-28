import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

sealed class SummaryEvent {}

final class SummaryProgressEvent extends SummaryEvent {
  final int progress;
  final String message;
  SummaryProgressEvent({required this.progress, required this.message});
}

final class SummaryDoneEvent extends SummaryEvent {}

final class SummaryErrorEvent extends SummaryEvent {
  final String message;
  SummaryErrorEvent({required this.message});
}

class SummaryService {
  final int port;
  final http.Client _httpClient;

  SummaryService({this.port = 8000, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
  }) async* {
    final uri = Uri.http('localhost:$port', '/summary/generate');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'party_members': partyMembers,
      });

    final response = await _httpClient.send(request);
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final payload = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      if (payload['done'] == true) {
        if (payload['error'] == true) {
          yield SummaryErrorEvent(
              message: payload['message']?.toString() ?? 'Unknown error');
        } else {
          yield SummaryDoneEvent();
        }
        return;
      }
      yield SummaryProgressEvent(
        progress: (payload['progress'] as num?)?.toInt() ?? 0,
        message: payload['message']?.toString() ?? '',
      );
    }
  }

  Future<String?> fetchSummary() async {
    final uri = Uri.http('localhost:$port', '/summary');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['summary'] as String?;
  }
}
