import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/state/typewriter_controller.dart';

void main() {
  group('TypewriterController', () {
    testWidgets('empty string is immediately done', (tester) async {
      final ctrl = TypewriterController(fullText: '');
      expect(ctrl.isDone, isTrue);
      expect(ctrl.displayedText, '');
      ctrl.dispose();
    });

    testWidgets('displayedText is empty before start', (tester) async {
      final ctrl = TypewriterController(fullText: 'Hello');
      expect(ctrl.displayedText, '');
      expect(ctrl.isDone, isFalse);
      ctrl.dispose();
    });

    testWidgets('one tick reveals one character', (tester) async {
      final ctrl = TypewriterController(
        fullText: 'Hi',
        interval: const Duration(milliseconds: 20),
      );
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 20));
      expect(ctrl.displayedText, 'H');
      ctrl.dispose();
    });

    testWidgets('reveals characters in order', (tester) async {
      final ctrl = TypewriterController(
        fullText: 'AB',
        interval: const Duration(milliseconds: 20),
      );
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 20));
      expect(ctrl.displayedText, 'A');
      await tester.pump(const Duration(milliseconds: 20));
      expect(ctrl.displayedText, 'AB');
      ctrl.dispose();
    });

    testWidgets('isDone after all characters revealed', (tester) async {
      final ctrl = TypewriterController(
        fullText: 'Hi',
        interval: const Duration(milliseconds: 20),
      );
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 40));
      expect(ctrl.isDone, isTrue);
      expect(ctrl.displayedText, 'Hi');
      ctrl.dispose();
    });

    testWidgets('notifyListeners called once per character', (tester) async {
      final ctrl = TypewriterController(
        fullText: 'ABC',
        interval: const Duration(milliseconds: 20),
      );
      int notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 60));
      expect(notifyCount, 3);
      ctrl.dispose();
    });

    testWidgets('no more notifications after full text revealed', (tester) async {
      final ctrl = TypewriterController(
        fullText: 'Hi',
        interval: const Duration(milliseconds: 20),
      );
      int notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 40));
      expect(notifyCount, 2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(notifyCount, 2);
      ctrl.dispose();
    });

    testWidgets('start on empty string does nothing', (tester) async {
      final ctrl = TypewriterController(fullText: '');
      int notifyCount = 0;
      ctrl.addListener(() => notifyCount++);
      ctrl.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(notifyCount, 0);
      ctrl.dispose();
    });
  });
}
