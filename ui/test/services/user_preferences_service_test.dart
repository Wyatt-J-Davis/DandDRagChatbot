import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/user_preferences_service.dart';

void main() {
  group('UserPreferencesService', () {
    late Directory tempDir;
    late File prefsFile;
    late UserPreferencesService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prefs_test_');
      prefsFile = File('${tempDir.path}/user_data.json');
      service = UserPreferencesService(file: prefsFile);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('load', () {
      test('returns defaults when file does not exist', () async {
        final prefs = await service.load();
        expect(prefs.model, isNull);
        expect(prefs.temperature, 0.5);
      });

      test('returns stored model', () async {
        prefsFile.writeAsStringSync(json.encode({'model': 'llama3', 'temperature': 0.7}));
        final prefs = await service.load();
        expect(prefs.model, 'llama3');
      });

      test('returns stored temperature', () async {
        prefsFile.writeAsStringSync(json.encode({'model': null, 'temperature': 0.8}));
        final prefs = await service.load();
        expect(prefs.temperature, 0.8);
      });

      test('returns default temperature when temperature key is missing', () async {
        prefsFile.writeAsStringSync(json.encode({'model': 'mistral'}));
        final prefs = await service.load();
        expect(prefs.temperature, 0.5);
      });

      test('returns null model when model key is missing', () async {
        prefsFile.writeAsStringSync(json.encode({'temperature': 0.6}));
        final prefs = await service.load();
        expect(prefs.model, isNull);
      });

      test('returns defaults when file contains malformed JSON', () async {
        prefsFile.writeAsStringSync('not valid json {{');
        final prefs = await service.load();
        expect(prefs.model, isNull);
        expect(prefs.temperature, 0.5);
      });
    });

    group('save then load', () {
      test('round-trips model and temperature', () async {
        await service.save(const UserPreferences(model: 'mistral', temperature: 0.3));
        final prefs = await service.load();
        expect(prefs.model, 'mistral');
        expect(prefs.temperature, closeTo(0.3, 0.001));
      });

      test('round-trips null model', () async {
        await service.save(const UserPreferences(model: null, temperature: 0.5));
        final prefs = await service.load();
        expect(prefs.model, isNull);
      });

      test('round-trips temperature of 0.0', () async {
        await service.save(const UserPreferences(model: null, temperature: 0.0));
        final prefs = await service.load();
        expect(prefs.temperature, 0.0);
      });

      test('round-trips temperature of 1.0', () async {
        await service.save(const UserPreferences(model: 'llama3', temperature: 1.0));
        final prefs = await service.load();
        expect(prefs.temperature, 1.0);
      });
    });
  });
}
