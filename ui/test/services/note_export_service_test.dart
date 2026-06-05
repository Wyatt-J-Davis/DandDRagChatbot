import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/note_export_service.dart';

void main() {
  group('NoteExportService', () {
    group('fetchTxtBytes', () {
      test('returns bytes from /notes/export/txt on 200', () async {
        final client = MockClient((_) async =>
            http.Response.bytes([104, 101, 108, 108, 111], 200));
        final service = NoteExportService(port: 9999, httpClient: client);

        final bytes = await service.fetchTxtBytes();

        expect(bytes, isNotNull);
        expect(bytes, equals([104, 101, 108, 108, 111]));
      });

      test('returns null on non-200 response', () async {
        final client = MockClient((_) async => http.Response('error', 404));
        final service = NoteExportService(port: 9999, httpClient: client);

        final bytes = await service.fetchTxtBytes();

        expect(bytes, isNull);
      });

      test('GETs /notes/export/txt on the configured port', () async {
        http.Request? captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response.bytes([1, 2, 3], 200);
        });
        final service = NoteExportService(port: 9999, httpClient: client);

        await service.fetchTxtBytes();

        expect(captured, isNotNull);
        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/notes/export/txt');
        expect(captured!.url.port, 9999);
      });
    });

    group('fetchDocxBytes', () {
      test('returns bytes from /notes/export/docx on 200', () async {
        final client = MockClient(
            (_) async => http.Response.bytes([80, 75, 3, 4], 200));
        final service = NoteExportService(port: 9999, httpClient: client);

        final bytes = await service.fetchDocxBytes();

        expect(bytes, isNotNull);
        expect(bytes, equals([80, 75, 3, 4]));
      });

      test('returns null on non-200 response', () async {
        final client = MockClient((_) async => http.Response('error', 404));
        final service = NoteExportService(port: 9999, httpClient: client);

        final bytes = await service.fetchDocxBytes();

        expect(bytes, isNull);
      });

      test('GETs /notes/export/docx on the configured port', () async {
        http.Request? captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response.bytes([1, 2, 3], 200);
        });
        final service = NoteExportService(port: 9999, httpClient: client);

        await service.fetchDocxBytes();

        expect(captured, isNotNull);
        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/notes/export/docx');
        expect(captured!.url.port, 9999);
      });
    });
  });

  group('timeout', () {
    test('fetchTxtBytes returns null when request hangs past timeout',
        () async {
      final completer = Completer<http.Response>();
      final client = MockClient((_) => completer.future);
      final service = NoteExportService(
        port: 9999,
        httpClient: client,
        requestTimeout: const Duration(milliseconds: 20),
      );

      final result = await service.fetchTxtBytes();

      expect(result, isNull);
    });

    test('fetchDocxBytes returns null when request hangs past timeout',
        () async {
      final completer = Completer<http.Response>();
      final client = MockClient((_) => completer.future);
      final service = NoteExportService(
        port: 9999,
        httpClient: client,
        requestTimeout: const Duration(milliseconds: 20),
      );

      final result = await service.fetchDocxBytes();

      expect(result, isNull);
    });
  });
}
