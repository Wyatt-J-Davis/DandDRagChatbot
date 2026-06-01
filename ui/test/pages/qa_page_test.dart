import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:ttrpg_chatbot/pages/qa_page.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';
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
  final List<ChatSource> sources;
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
    return StreamController<ChatEvent>().stream;
  }
}

class _LongAnswerChatService extends ChatService {
  final String answer;
  _LongAnswerChatService(this.answer);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: answer, sources: []);
  }
}

class _SourcedLongAnswerChatService extends ChatService {
  final String answer;
  final List<ChatSource> sources;
  _SourcedLongAnswerChatService(this.answer, this.sources);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: answer, sources: sources);
  }
}

Widget buildSubject({ChatService? chatService}) {
  final appState = AppStateNotifier(initialModel: 'llama3');
  return MaterialApp(
    home: Scaffold(
      body: QAPage(
        appState: appState,
        operationManager: OperationManager(
          appState: appState,
          chatService: chatService ?? _NoOpChatService(),
        ),
      ),
    ),
  );
}

void main() {
  group('QAPage', () {
    group('welcome state', () {
      testWidgets('empty chat shows wizard emoji', (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('🧙'), findsOneWidget);
      });

      testWidgets('empty chat has no message list', (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byType(ListView), findsNothing);
      });

      testWidgets('wizard emoji disappears once first message is sent',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(find.text('🧙'), findsNothing);
      });

      testWidgets('message list appears once first message is sent',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(find.byType(ListView), findsOneWidget);
      });
    });

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
      // 500ms per pump so the 18-char typewriter (18×20ms=360ms) completes
      // in a single pump iteration — pumpAndSettle with 100ms/iter only drives
      // ~300ms (scroll animation duration) before hasScheduledFrame goes false.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

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

    testWidgets('text field is disabled while waiting for response',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _HangingChatService()));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
    });

    testWidgets('text field is re-enabled after answer arrives',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _AnswerChatService('The answer')));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isNotNull);
      expect(tf.enabled, isNot(false));
    });

    testWidgets('text field is re-enabled after error arrives',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(chatService: _ErrorChatService('Model not found')));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isNotNull);
      expect(tf.enabled, isNot(false));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
            const ChatSource(content: 'chunk b', date: null),
          ])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ReferenceChip), findsNWidgets(2));
    });

    testWidgets('chip labels show date when source has a date',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: '2023-10-27'),
            const ChatSource(content: 'chunk b', date: '2024-03-15'),
          ])));
      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('2023-10-27'), findsOneWidget);
      expect(find.text('2024-03-15'), findsOneWidget);
    });

    testWidgets('chip labels fall back to "Source N" when date is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
            const ChatSource(content: 'chunk b', date: null),
          ])));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
          ])));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
          ])));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'The goblin king rules here.', date: null),
          ])));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
          ])));
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
          chatService: _SourcedAnswerChatService([
            const ChatSource(content: 'chunk a', date: null),
          ])));
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

    group('thinking animation', () {
      testWidgets('star-magic Lottie visible while bot is thinking',
          (WidgetTester tester) async {
        await tester.pumpWidget(
            buildSubject(chatService: _HangingChatService()));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.byType(Lottie), findsOneWidget);
      });

      testWidgets('star-magic Lottie not visible when idle',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byType(Lottie), findsNothing);
      });

      testWidgets('inference Lottie is inside the message ListView while loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
            buildSubject(chatService: _HangingChatService()));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Lottie),
          ),
          findsOneWidget,
        );
      });

      testWidgets('star-magic Lottie disappears after answer arrives',
          (WidgetTester tester) async {
        await tester.pumpWidget(
            buildSubject(chatService: _AnswerChatService('Hello')));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.byType(Lottie), findsNothing);
      });

      testWidgets('inference Lottie renders at 720x720 while bot is thinking',
          (WidgetTester tester) async {
        await tester.pumpWidget(
            buildSubject(chatService: _HangingChatService()));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final lottie = tester.widget<Lottie>(find.byType(Lottie));
        expect(lottie.width, 720);
        expect(lottie.height, 720);
      });
    });

    group('input placeholder', () {
      testWidgets('shows campaign-focused placeholder in empty state',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.decoration?.hintText, 'Ask a question about the campaign…');
      });

      testWidgets('shows campaign-focused placeholder in active-chat state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
            buildSubject(chatService: _HangingChatService()));
        await tester.enterText(find.byType(TextField), 'First question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.decoration?.hintText, 'Ask a question about the campaign…');
      });
    });

    group('centered layout', () {
      testWidgets('empty state input is constrained to maxWidth 720',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());

        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(
          constrainedBoxes.any((cb) => cb.constraints.maxWidth == 720),
          isTrue,
        );
      });

      testWidgets('message list is wrapped in a ConstrainedBox with maxWidth 720',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.ancestor(
            of: find.byType(ListView),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(
          constrainedBoxes.any((cb) => cb.constraints.maxWidth == 720),
          isTrue,
        );
      });

      testWidgets('input row is wrapped in a ConstrainedBox with maxWidth 720 in active chat',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(
          constrainedBoxes.any((cb) => cb.constraints.maxWidth == 720),
          isTrue,
        );
      });

      testWidgets('input area has a rounded border container',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());

        final containers = tester.widgetList<Container>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          ),
        );
        expect(
          containers.any((c) {
            final deco = c.decoration;
            return deco is BoxDecoration && deco.borderRadius != null;
          }),
          isTrue,
        );
      });
    });

    group('typewriter effect', () {
      testWidgets('answer bubble shows partial text immediately after arriving',
          (WidgetTester tester) async {
        const fullAnswer = 'ABCDEFGHIJ';
        await tester.pumpWidget(
            buildSubject(chatService: _LongAnswerChatService(fullAnswer)));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        // Answer arrived, typewriter started — advance exactly 2 ticks (4ms at 2ms interval)
        await tester.pump(const Duration(milliseconds: 4));

        expect(find.text('AB'), findsOneWidget);
        expect(find.text(fullAnswer), findsNothing);
      });

      testWidgets('answer bubble shows full text after typing completes',
          (WidgetTester tester) async {
        const fullAnswer = 'ABCDE';
        await tester.pumpWidget(
            buildSubject(chatService: _LongAnswerChatService(fullAnswer)));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text(fullAnswer), findsOneWidget);
      });

      testWidgets('reference chips suppressed while typing',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
            chatService: _SourcedLongAnswerChatService(
          'ABCDEFGHIJ',
          [const ChatSource(content: 'src', date: null)],
        )));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        // Typewriter has only revealed a few chars (4ms = 2 ticks at 2ms interval)
        await tester.pump(const Duration(milliseconds: 4));

        expect(find.byType(ReferenceChip), findsNothing);
      });

      testWidgets('reference chips appear after typing completes',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
            chatService: _SourcedLongAnswerChatService(
          'ABCDE',
          [const ChatSource(content: 'src', date: null)],
        )));
        await tester.enterText(find.byType(TextField), 'question');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceChip), findsOneWidget);
      });
    });
  });
}
