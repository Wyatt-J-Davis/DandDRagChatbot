import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/backend_service.dart';

// Fake Process that records whether kill() was called.
class _FakeProcess implements Process {
  bool killed = false;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 0;
}

// Fake Process whose stdout/stderr are single-subscription streams backed by
// controllers, so a test can push data and observe that the streams are drained.
class _StreamingFakeProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();

  bool get stdoutHasListener => _stdoutController.hasListener;
  bool get stderrHasListener => _stderrController.hasListener;

  void emitStdout(List<int> data) => _stdoutController.add(data);
  void emitStderr(List<int> data) => _stderrController.add(data);

  Future<void> closeStreams() async {
    await _stdoutController.close();
    await _stderrController.close();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 0;
}

Future<Process> _stubStarter(String exe, List<String> args) async =>
    _FakeProcess();

void main() {
  group('BackendService', () {
    test('ready completes when /health returns 200 immediately', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response('ok', 200);
      });

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: _stubStarter,
      );

      await service.start();
      await service.ready.timeout(const Duration(seconds: 2));
      await service.dispose();
    });

    test('ready completes after retrying when /health returns non-200 first',
        () async {
      int callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.Response('not ready', 503);
        }
        return http.Response('ok', 200);
      });

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: _stubStarter,
        pollInterval: const Duration(milliseconds: 10),
      );

      await service.start();
      await service.ready.timeout(const Duration(seconds: 2));

      expect(callCount, greaterThanOrEqualTo(3));
      await service.dispose();
    });

    test(
        'ready completes after retrying when /health throws a connection error first',
        () async {
      int callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        if (callCount < 2) {
          throw const SocketException('Connection refused');
        }
        return http.Response('ok', 200);
      });

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: _stubStarter,
        pollInterval: const Duration(milliseconds: 10),
      );

      await service.start();
      await service.ready.timeout(const Duration(seconds: 2));
      await service.dispose();
    });

    test('dispose() kills the child process', () async {
      final fakeProcess = _FakeProcess();

      final client = MockClient((_) async => http.Response('ok', 200));

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: (exe, args) async => fakeProcess,
      );

      await service.start();
      await service.ready.timeout(const Duration(seconds: 2));
      await service.dispose();

      expect(fakeProcess.killed, isTrue);
    });

    test('start() drains the child process stdout and stderr', () async {
      final fakeProcess = _StreamingFakeProcess();

      final client = MockClient((_) async => http.Response('ok', 200));

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: (exe, args) async => fakeProcess,
      );

      await service.start().timeout(const Duration(seconds: 2));
      await service.ready.timeout(const Duration(seconds: 2));

      // Both output streams must have a subscriber so the OS pipe can drain.
      expect(fakeProcess.stdoutHasListener, isTrue);
      expect(fakeProcess.stderrHasListener, isTrue);

      // Pushing data and closing must complete without hanging the start path.
      fakeProcess.emitStdout(const [104, 105]);
      fakeProcess.emitStderr(const [98, 121, 101]);
      await fakeProcess.closeStreams().timeout(const Duration(seconds: 2));

      await service.dispose();
    });

    test('start() passes executablePath to the process starter', () async {
      const expectedPath = '/path/to/backend.exe';
      String? capturedPath;

      final client = MockClient((_) async => http.Response('ok', 200));

      final service = BackendService(
        executablePath: expectedPath,
        port: 9999,
        httpClient: client,
        processStarter: (path, args) async {
          capturedPath = path;
          return _FakeProcess();
        },
      );

      await service.start();
      await service.ready.timeout(const Duration(seconds: 2));
      await service.dispose();

      expect(capturedPath, expectedPath);
    });
  });
}
