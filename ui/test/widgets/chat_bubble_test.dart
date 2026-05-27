import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/chat_bubble.dart';

Widget buildSubject({
  required String message,
  required ChatSender sender,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: ChatBubble(message: message, sender: sender)),
  );
}

void main() {
  group('ChatBubble', () {
    testWidgets('displays message text', (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(message: 'Hello world', sender: ChatSender.user));
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('user bubble aligns to the right', (WidgetTester tester) async {
      await tester
          .pumpWidget(buildSubject(message: 'hi', sender: ChatSender.user));
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('assistant bubble aligns to the left',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(message: 'hi', sender: ChatSender.assistant));
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('user bubble uses primary color background',
        (WidgetTester tester) async {
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(primary: Color(0xFFFF0000)),
      );
      await tester.pumpWidget(
          buildSubject(message: 'hi', sender: ChatSender.user, theme: theme));
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, theme.colorScheme.primary);
    });

    testWidgets('assistant bubble uses surfaceVariant color background',
        (WidgetTester tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.light(
            surfaceVariant: const Color(0xFF00FF00)),
      );
      await tester.pumpWidget(buildSubject(
          message: 'hi', sender: ChatSender.assistant, theme: theme));
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, theme.colorScheme.surfaceVariant);
    });
  });
}
