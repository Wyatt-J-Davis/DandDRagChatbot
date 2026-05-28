import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/qa_page.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/chat_bubble.dart';
import 'package:ttrpg_chatbot/widgets/reference_chip.dart';

class _NoOpChatService extends ChatService {
  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {}
}

class _AnswerChatService extends ChatService {
  final String answer;
  _AnswerChatService(this.answer);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: answer, sources: []);
  }
}

class _ErrorChatService extends ChatService {
  final String errorMessage;
  _ErrorChatService(this.errorMessage);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatErrorEvent(message: errorMessage);
  }
}

class _SourcedAnswerChatService extends ChatService {
  final List<String> sources;
  _SourcedAnswerChatService(this.sources);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: 'The answer', sources: sources);
  }
}

class _HangingChatService extends ChatService {
  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) {
    // Never emits and never closes — no pending timers.
    return StreamController<ChatEvent>().stream;
  }
}

Widget buildSubject({ChatService? chatService}) {
  return MaterialApp(
    home: Scaffold(
      body: QAPage(
        appState: AppStateNotifier(initialModel: 'llama3'),
        chatService: chatService ?? _NoOpChatService(),
      ),
    ),
  );
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

    testWidgets('tapping submit button adds a user ChatBubble',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'What happened in session 3?');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final bubbles = tester.widgetList<ChatBubble>(find.byType(ChatBubble));
      expect(bubbles.any((b) =>
              b.sender == ChatSender.user &&
              b.message == 'What happened in session 3?'),
          isTrue);
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

    testWidgets('assistant ChatBubble appears after ChatAnswerEvent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _AnswerChatService('The dragon is red.')));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final bubbles = tester.widgetList<ChatBubble>(find.byType(ChatBubble));
      expect(bubbles.any((b) => b.sender == ChatSender.assistant), isTrue);
      expect(find.text('The dragon is red.'), findsOneWidget);
    });

    testWidgets('assistant ChatBubble appears with error text after ChatErrorEvent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _ErrorChatService('Model not found')));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final bubbles = tester.widgetList<ChatBubble>(find.byType(ChatBubble));
      expect(bubbles.any((b) => b.sender == ChatSender.assistant), isTrue);
      expect(find.text('Error: Model not found'), findsOneWidget);
    });

    testWidgets('send button is disabled while waiting for response',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _HangingChatService()));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('four bubbles visible after two question-answer cycles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _AnswerChatService('The answer')));

      await tester.enterText(find.byType(TextField), 'First question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Second question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ChatBubble), findsNWidgets(4));
    });

    testWidgets('reference chips appear when answer has sources',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a', 'chunk b'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ReferenceChip), findsNWidgets(2));
    });

    testWidgets('chip labels are "Source 1", "Source 2", etc.',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a', 'chunk b'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Source 1'), findsOneWidget);
      expect(find.text('Source 2'), findsOneWidget);
    });

    testWidgets('no reference chips when answer has no sources',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _AnswerChatService('The answer')));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ReferenceChip), findsNothing);
    });

    testWidgets('no reference chips for user messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final chips = tester.widgetList<ReferenceChip>(find.byType(ReferenceChip));
      expect(chips.length, 1);
    });

    testWidgets('tapping a reference chip opens a dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('dialog displays the source chunk text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['The goblin king rules here.'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      expect(find.text('The goblin king rules here.'), findsOneWidget);
    });

    testWidgets('dialog close button dismisses the dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('dialog content is scrollable',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService(['chunk a'])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('prior messages remain visible after second submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _AnswerChatService('The answer')));

      await tester.enterText(find.byType(TextField), 'First question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Second question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('First question'), findsOneWidget);
      expect(find.text('Second question'), findsOneWidget);
      expect(find.text('The answer'), findsNWidgets(2));
    });
  });
}
