import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';

void main() {
  group('AppStateNotifier', () {
    test('selectedModel is null initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.selectedModel, isNull);
    });

    test('setSelectedModel updates selectedModel', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');
      expect(notifier.selectedModel, 'llama3');
    });

    test('setSelectedModel notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setSelectedModel('llama3');
      expect(callCount, 1);
    });

    test('setSelectedModel does not notify when value is unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');

      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setSelectedModel('llama3');
      expect(callCount, 0);
    });

    test('setSelectedModel accepts null to clear selection', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');
      notifier.setSelectedModel(null);
      expect(notifier.selectedModel, isNull);
    });
  });

  group('temperature', () {
    test('temperature is 0.5 initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.temperature, 0.5);
    });

    test('setTemperature updates temperature', () {
      final notifier = AppStateNotifier();
      notifier.setTemperature(0.8);
      expect(notifier.temperature, 0.8);
    });

    test('setTemperature notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setTemperature(0.8);
      expect(callCount, 1);
    });

    test('setTemperature does not notify when value is unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setTemperature(0.8);

      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setTemperature(0.8);
      expect(callCount, 0);
    });
  });
}
