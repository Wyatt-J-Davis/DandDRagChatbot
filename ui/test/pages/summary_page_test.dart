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
  Future<SummaryResult?> fetchSummary() async => null;
}

class _HangingSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) {
    return StreamController<SummaryEvent>().stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
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
  Future<SummaryResult?> fetchSummary() async => null;
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
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'The campaign summary text.');
}

class _DoneSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'The campaign summary text.');
}

class _ErrorSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryErrorEvent(message: 'Model not found');
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _TrackingNullFetchService extends SummaryService {
  int fetchCount = 0;

  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async {
    fetchCount++;
    return null;
  }
}

class _SummaryWithSectionsFetchService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async => SummaryResult(
      summary:
          '# Introduction\nThe campaign begins.\n\n# The Adventure\nThe heroes set out.');
}

class _PlainSummaryFetchService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'Plain summary with no headings.');
}

class _SummaryWithMetadataService extends SummaryService {
  final String? model;
  final String? generatedAt;
  _SummaryWithMetadataService({this.model, this.generatedAt});

  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async => SummaryResult(
        summary: 'The campaign summary text.',
        model: model,
        generatedAt: generatedAt,
      );
}

class _LoadedThenHangService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) {
    return StreamController<SummaryEvent>().stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'Existing summary.');
}

class _LoadedThenProgressAndHangService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) {
    final controller = StreamController<SummaryEvent>();
    controller.add(SummaryProgressEvent(progress: 50, message: 'Summarizing...'));
    return controller.stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'Existing summary.');
}

class _LoadedThenDoneService extends SummaryService {
  int _fetchCount = 0;

  @override
  Stream<SummaryEvent> generate(
      {required String model, required List<String> partyMembers}) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<SummaryResult?> fetchSummary() async {
    _fetchCount++;
    if (_fetchCount == 1) return SummaryResult(summary: 'Old summary.');
    return SummaryResult(summary: 'New summary.');
  }
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

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Summary'));
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

  group('SummaryPage (on-load fetch and TOC)', () {
    testWidgets('fetches summary from service on page load',
        (WidgetTester tester) async {
      final service = _TrackingNullFetchService();
      await tester.pumpWidget(buildSubject(summaryService: service));
      await tester.pumpAndSettle();

      expect(service.fetchCount, 1);
    });

    testWidgets('shows "no summary" prompt when fetchSummary returns null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _TrackingNullFetchService()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No summary yet'), findsOneWidget);
    });

    testWidgets('"no summary" prompt not shown while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.textContaining('No summary yet'), findsNothing);
    });

    testWidgets('shows section headings when summary has headings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _SummaryWithSectionsFetchService()));
      await tester.pumpAndSettle();

      expect(find.text('Introduction'), findsWidgets);
      expect(find.text('The Adventure'), findsWidgets);
    });

    testWidgets('shows a ListTile per section heading in the table of contents',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _SummaryWithSectionsFetchService()));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('tapping a TOC entry does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _SummaryWithSectionsFetchService()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
    });

    testWidgets('summary content is inside a SingleChildScrollView',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _SummaryWithSectionsFetchService()));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('summary without headings is displayed as plain text without TOC',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _PlainSummaryFetchService()));
      await tester.pumpAndSettle();

      expect(find.text('Plain summary with no headings.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('SummaryPage (metadata display)', () {
    testWidgets('shows model name in subtitle when summary has model metadata',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _SummaryWithMetadataService(
              model: 'llama3', generatedAt: '2026-05-27T10:00:00')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Model: llama3'), findsOneWidget);
    });

    testWidgets('shows generation date in subtitle when summary has generatedAt',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _SummaryWithMetadataService(
              model: 'llama3', generatedAt: '2026-05-27T10:00:00')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Generated: 2026-05-27'), findsOneWidget);
    });

    testWidgets('shows only model when generatedAt is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService:
              _SummaryWithMetadataService(model: 'llama3', generatedAt: null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Model: llama3'), findsOneWidget);
      expect(find.textContaining('Generated:'), findsNothing);
    });

    testWidgets('shows only date when model is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _SummaryWithMetadataService(
              model: null, generatedAt: '2026-05-27T10:00:00')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Generated: 2026-05-27'), findsOneWidget);
      expect(find.textContaining('Model:'), findsNothing);
    });

    testWidgets('shows no metadata subtitle when both model and generatedAt are null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService:
              _SummaryWithMetadataService(model: null, generatedAt: null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Model:'), findsNothing);
      expect(find.textContaining('Generated:'), findsNothing);
    });
  });

  group('SummaryPage (regenerate button)', () {
    testWidgets('Regenerate button not visible when no summary exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _TrackingNullFetchService()));
      await tester.pumpAndSettle();

      expect(find.text('Regenerate'), findsNothing);
    });

    testWidgets('Regenerate button visible when a summary is loaded',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _LoadedThenHangService()));
      await tester.pumpAndSettle();

      expect(find.text('Regenerate'), findsOneWidget);
    });

    testWidgets('Regenerate button is disabled while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _LoadedThenHangService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Regenerate'));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping Regenerate shows progress messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _LoadedThenProgressAndHangService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Summarizing...'), findsOneWidget);
    });

    testWidgets('after regeneration done, new summary is displayed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _LoadedThenDoneService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();

      expect(find.text('New summary.'), findsOneWidget);
    });
  });
}
