import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/summary_page.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';

class _NoOpSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {}

  @override
  Future<String?> fetchSummary() async => null;
}

class _HangingSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) {
    return StreamController<SummaryEvent>().stream;
  }

  @override
  Future<String?> fetchSummary() async => null;
}

class _ProgressAndHangSummaryService extends SummaryService {
  final String progressMessage;
  _ProgressAndHangSummaryService(this.progressMessage);

  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) {
    final controller = StreamController<SummaryEvent>();
    controller.add(SummaryProgressEvent(progress: 30, message: progressMessage));
    // Never closes — hangs after the progress event.
    return controller.stream;
  }

  @override
  Future<String?> fetchSummary() async => null;
}

class _ProgressThenDoneSummaryService extends SummaryService {
  final String progressMessage;
  _ProgressThenDoneSummaryService(this.progressMessage);

  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryProgressEvent(progress: 30, message: progressMessage);
    yield SummaryDoneEvent();
  }

  @override
  Future<String?> fetchSummary() async => 'The campaign summary text.';
}

class _DoneSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<String?> fetchSummary() async => 'The campaign summary text.';
}

class _ErrorSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryErrorEvent(message: 'Model not found');
  }

  @override
  Future<String?> fetchSummary() async => null;
}

Widget buildSubject({SummaryService? summaryService}) {
  return MaterialApp(
    home: Scaffold(
      body: SummaryPage(
        appState: AppStateNotifier(initialModel: 'llama3'),
        summaryService: summaryService ?? _NoOpSummaryService(),
      ),
    ),
  );
}

void main() {
  group('SummaryPage', () {
    testWidgets('"Generate Summary" button is visible initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Generate Summary'), findsOneWidget);
    });

    testWidgets('button is enabled initially', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('button is disabled while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('LinearProgressIndicator visible while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress message displayed during generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Summarizing section 1 of 3...')));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Summarizing section 1 of 3...'), findsOneWidget);
    });

    testWidgets('phase label "Map" visible for Summarizing message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Summarizing section 1 of 3...')));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Map'), findsOneWidget);
    });

    testWidgets('phase label "Reduce" visible for Combining message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Combining summaries (pass 1)...')));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Reduce'), findsOneWidget);
    });

    testWidgets('phase label "Synthesis" visible for Writing message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Writing final campaign summary...')));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Synthesis'), findsOneWidget);
    });

    testWidgets('after done: LinearProgressIndicator is gone',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('after done: summary text is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.text('The campaign summary text.'), findsOneWidget);
    });

    testWidgets('after error: error text is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _ErrorSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Error: Model not found'), findsOneWidget);
    });

    testWidgets('after done: button is re-enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('after error: button is re-enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _ErrorSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
