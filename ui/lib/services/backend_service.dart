import 'dart:io';

import 'package:http/http.dart' as http;

typedef ProcessStarter = Future<Process> Function(
    String executable, List<String> arguments);

class BackendService {
  final String executablePath;
  final int port;
  final Duration pollInterval;
  final http.Client _httpClient;
  final ProcessStarter _processStarter;

  Process? _process;
  late final Future<void> ready;

  BackendService({
    required this.executablePath,
    this.port = 8000,
    this.pollInterval = const Duration(milliseconds: 500),
    http.Client? httpClient,
    ProcessStarter? processStarter,
  })  : _httpClient = httpClient ?? http.Client(),
        _processStarter = processStarter ?? Process.start;

  Future<void> start() async {
    _process = await _processStarter(executablePath, []);
    ready = _pollUntilReady();
  }

  Future<void> _pollUntilReady() async {
    final uri = Uri.http('localhost:$port', '/health');
    while (true) {
      try {
        final response = await _httpClient.get(uri);
        if (response.statusCode == 200) return;
      } on Exception {
        // connection refused or similar — keep polling
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> dispose() async {
    _process?.kill();
    _httpClient.close();
  }
}
