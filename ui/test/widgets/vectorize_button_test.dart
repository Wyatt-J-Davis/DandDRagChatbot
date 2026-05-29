import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/vectorize_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';
import 'package:ttrpg_chatbot/widgets/vectorize_button.dart';

class _FakeVectorizeService extends VectorizeService {
  final Stream<VectorizeEvent> Function(String) _fn;

  _FakeVectorizeService(this._fn) : super(httpClient: null);

  @override
  Stream<VectorizeEvent> vectorize(String plainText) => _fn(plainText);
}

Widget buildSubject({
  required QuillController controller,
  required VectorizeService service,
}) {
  final appState = AppStateNotifier();
  return MaterialApp(
    localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
    supportedLocales: FlutterQuillLocalizations.supportedLocales,
    home: Scaffold(
      body: VectorizeButton(
        controller: controller,
        operationManager: OperationManager(
          appState: appState,
          vectorizeService: service,
        ),
      ),
    ),
  );
}

void main() {
  group('VectorizeButton', () {
    late QuillController controller;

    setUp(() => controller = QuillController.basic());
    tearDown(() => controller.dispose());

    testWidgets('shows Vectorize button', (tester) async {
      final service = _FakeVectorizeService((_) => const Stream.empty());
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      expect(find.widgetWithText(ElevatedButton, 'Vectorize'), findsOneWidget);
    });

    testWidgets('button is enabled when not vectorizing', (tester) async {
      final service = _FakeVectorizeService((_) => const Stream.empty());
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Vectorize'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('button is disabled while vectorizing', (tester) async {
      final completer = Completer<void>();
      final service = _FakeVectorizeService(
        (_) => Stream.fromFuture(completer.future).asyncExpand((_) async* {}),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Vectorize'),
      );
      expect(btn.onPressed, isNull);

      completer.complete();
    });

    testWidgets('shows LinearProgressIndicator while vectorizing',
        (tester) async {
      final completer = Completer<void>();
      final service = _FakeVectorizeService(
        (_) => Stream.fromFuture(completer.future).asyncExpand((_) async* {}),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      completer.complete();
    });

    testWidgets('shows success message when done event arrives', (tester) async {
      final service = _FakeVectorizeService(
        (_) => Stream.value(VectorizeDoneEvent()),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('Vectorization complete'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows error message when error event arrives', (tester) async {
      final service = _FakeVectorizeService(
        (_) => Stream.value(VectorizeErrorEvent(message: 'DB down')),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('DB down'), findsOneWidget);
    });

    testWidgets('hides progress indicator after done', (tester) async {
      final service = _FakeVectorizeService(
        (_) => Stream.value(VectorizeDoneEvent()),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows toast snackbar on successful vectorization',
        (tester) async {
      final service = _FakeVectorizeService(
        (_) => Stream.value(VectorizeDoneEvent()),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Notes vectorized successfully'), findsOneWidget);
    });

    testWidgets('no toast snackbar on vectorization error', (tester) async {
      final service = _FakeVectorizeService(
        (_) => Stream.value(VectorizeErrorEvent(message: 'DB down')),
      );
      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sends plain text extracted from Quill delta', (tester) async {
      String? capturedText;
      final service = _FakeVectorizeService((text) {
        capturedText = text;
        return Stream.value(VectorizeDoneEvent());
      });

      controller.document.insert(0, 'Campaign notes here');

      await tester.pumpWidget(buildSubject(
        controller: controller,
        service: service,
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
      await tester.pumpAndSettle();

      expect(capturedText, contains('Campaign notes here'));
    });
  });
}
