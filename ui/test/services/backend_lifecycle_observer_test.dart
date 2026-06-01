import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/backend_lifecycle_observer.dart';
import 'package:ttrpg_chatbot/services/backend_service.dart';

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

void main() {
  group('BackendLifecycleObserver', () {
    test('didRequestAppExit kills the backend process and returns exit', () async {
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

      final observer = BackendLifecycleObserver(backendService: service);
      final result = await observer.didRequestAppExit();

      expect(fakeProcess.killed, isTrue);
      expect(result, AppExitResponse.exit);
    });

    test('didRequestAppExit kills backend even before ready completes', () async {
      final fakeProcess = _FakeProcess();
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(hours: 1));
        return http.Response('ok', 200);
      });

      final service = BackendService(
        executablePath: 'fake_exe',
        port: 9999,
        httpClient: client,
        processStarter: (exe, args) async => fakeProcess,
      );
      await service.start();

      final observer = BackendLifecycleObserver(backendService: service);
      final result = await observer.didRequestAppExit();

      expect(fakeProcess.killed, isTrue);
      expect(result, AppExitResponse.exit);
    });
  });
}
