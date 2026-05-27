import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';

void main() {
  group('ModelService', () {
    test('fetchModels returns list of model names on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/models');
        return http.Response('["llama3", "mistral"]', 200);
      });

      final service = ModelService(port: 9999, httpClient: client);
      final models = await service.fetchModels();

      expect(models, ['llama3', 'mistral']);
    });

    test('fetchModels returns empty list when response is empty array', () async {
      final client = MockClient(
        (_) async => http.Response('[]', 200),
      );

      final service = ModelService(port: 9999, httpClient: client);
      final models = await service.fetchModels();

      expect(models, isEmpty);
    });

    test('fetchModels throws on non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );

      final service = ModelService(port: 9999, httpClient: client);
      expect(() => service.fetchModels(), throwsException);
    });

    test('fetchModels hits correct port', () async {
      Uri? capturedUri;

      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('[]', 200);
      });

      final service = ModelService(port: 8765, httpClient: client);
      await service.fetchModels();

      expect(capturedUri?.port, 8765);
    });
  });
}
