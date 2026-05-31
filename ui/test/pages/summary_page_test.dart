import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:ttrpg_chatbot/pages/summary_page.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';

class _NoOpSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _HangingSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) {
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
      {required String model,
      required List<String> partyMembers,
      required double temperature}) {
    final controller = StreamController<SummaryEvent>();
    controller.add(SummaryProgressEvent(progress: 30, message: progressMessage));
    // Never closes — hangs after the progress event.
    return controller.stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _DoneSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'The campaign summary text.');
}

class _ErrorSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {
    yield SummaryErrorEvent(message: 'Model not found');
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _TrackingNullFetchService extends SummaryService {
  int fetchCount = 0;

  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async {
    fetchCount++;
    return null;
  }
}

class _SummaryWithSectionsFetchService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async => SummaryResult(
      summary:
          '# Introduction\nThe campaign begins.\n\n# The Adventure\nThe heroes set out.');
}

class _BoldHeadingsSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async => SummaryResult(
      summary:
          '# **Overview**\nThe campaign begins.\n\n# **Journey**\nThe heroes set out.');
}

class _PlainSummaryFetchService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

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
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {}

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
      {required String model,
      required List<String> partyMembers,
      required double temperature}) {
    return StreamController<SummaryEvent>().stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'Existing summary.');
}

class _LoadedThenProgressAndHangService extends SummaryService {
  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) {
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
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<SummaryResult?> fetchSummary() async {
    _fetchCount++;
    if (_fetchCount == 1) return SummaryResult(summary: 'Old summary.');
    return SummaryResult(summary: 'New summary.');
  }
}

class _CapturingTemperatureService extends SummaryService {
  double? capturedTemperature;

  @override
  Stream<SummaryEvent> generate(
      {required String model,
      required List<String> partyMembers,
      required double temperature}) async* {
    capturedTemperature = temperature;
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

Widget buildSubject({SummaryService? summaryService, AppStateNotifier? appState}) {
  final theAppState = appState ?? AppStateNotifier(initialModel: 'llama3');
  final theService = summaryService ?? _NoOpSummaryService();
  return MaterialApp(
    home: Scaffold(
      body: SummaryPage(
        appState: theAppState,
        operationManager: OperationManager(
          appState: theAppState,
          summaryService: theService,
        ),
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
      await tester.pumpAndSettle();
      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('button is disabled while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      expect(button.onPressed, isNull);
    });

    testWidgets('Lottie animation visible while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.byType(Lottie), findsOneWidget);
    });

    testWidgets('Lottie animation is 240x240 while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      final size = tester.getSize(find.byType(Lottie));
      expect(size.width, 240);
      expect(size.height, 240);
    });

    testWidgets('Lottie animation not shown when idle',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets('LinearProgressIndicator visible while generating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _HangingSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress message displayed during generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Summarizing section 1 of 3...')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Summarizing section 1 of 3...'), findsOneWidget);
    });

    testWidgets('phase label "Map" visible for Summarizing message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Summarizing section 1 of 3...')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Map'), findsOneWidget);
    });

    testWidgets('phase label "Reduce" visible for Combining message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Combining summaries (pass 1)...')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Reduce'), findsOneWidget);
    });

    testWidgets('phase label "Synthesis" visible for Writing message',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(
          summaryService: _ProgressAndHangSummaryService(
              'Writing final campaign summary...')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      expect(find.text('Synthesis'), findsOneWidget);
    });

    testWidgets('Lottie animation disappears after generation completes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets('Lottie animation disappears after generation errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _ErrorSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets('after done: LinearProgressIndicator is gone',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('after done: summary text is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.text('The campaign summary text.'), findsOneWidget);
    });

    testWidgets('after error: error text is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _ErrorSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Error: Model not found'), findsOneWidget);
    });

    testWidgets('after done: button is re-enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows toast snackbar on successful summary generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _DoneSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Summary generated successfully'), findsOneWidget);
    });

    testWidgets('no toast snackbar on summary error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _ErrorSummaryService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('SummaryPage (temperature threading)', () {
    testWidgets('_generate passes appState.temperature to startSummary',
        (WidgetTester tester) async {
      final capturingSvc = _CapturingTemperatureService();
      final appState = AppStateNotifier(
          initialModel: 'llama3', initialTemperature: 0.3);
      await tester.pumpWidget(
          buildSubject(summaryService: capturingSvc, appState: appState));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Summary'));
      await tester.pumpAndSettle();

      expect(capturingSvc.capturedTemperature, 0.3);
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
      await tester.pumpAndSettle();
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

    testWidgets('section headings with bold markers are displayed without asterisks',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _BoldHeadingsSummaryService()));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('**Overview**'), findsNothing);
    });

    testWidgets('plain summary (no headings) renders via MarkdownBody',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _PlainSummaryFetchService()));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('section body renders via MarkdownBody',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildSubject(summaryService: _SummaryWithSectionsFetchService()));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsWidgets);
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
