import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/qa_page.dart';

Widget buildSubject() {
  return const MaterialApp(home: Scaffold(body: QAPage()));
}

void main() {
  group('QAPage', () {
    testWidgets('text field is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('submit button is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('submit button disabled when input is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('submit button enabled when input is non-empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping submit button captures input text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'What happened in session 3?');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(find.text('What happened in session 3?'), findsOneWidget);
    });

    testWidgets('tapping submit button clears the input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, isEmpty);
    });

    testWidgets('pressing Enter captures input text', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'Where is the dungeon?');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Where is the dungeon?'), findsOneWidget);
    });

    testWidgets('pressing Enter clears the input field', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, isEmpty);
    });
  });
}
