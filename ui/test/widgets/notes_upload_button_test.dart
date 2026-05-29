import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';
import 'package:ttrpg_chatbot/widgets/notes_upload_button.dart';

class _FakePickerService extends FilePickerService {
  final String? returnPath;
  int callCount = 0;

  _FakePickerService({this.returnPath});

  @override
  Future<String?> pickNotesFile() async {
    callCount++;
    return returnPath;
  }
}

class _FakeUploadService extends UploadService {
  final List<UploadEvent> events;
  String? capturedPath;

  _FakeUploadService({required this.events});

  @override
  Stream<UploadEvent> uploadNotes(String filePath) async* {
    capturedPath = filePath;
    for (final e in events) {
      yield e;
    }
  }
}

class _BlockingUploadService extends UploadService {
  final StreamController<UploadEvent> controller =
      StreamController<UploadEvent>();

  @override
  Stream<UploadEvent> uploadNotes(String _) => controller.stream;
}

class _CountingUploadService extends UploadService {
  final void Function() onCall;
  final List<UploadEvent> events;

  _CountingUploadService({required this.onCall, required this.events});

  @override
  Stream<UploadEvent> uploadNotes(String _) async* {
    onCall();
    for (final e in events) {
      yield e;
    }
  }
}

Widget buildSubject({
  AppStateNotifier? appState,
  FilePickerService? pickerService,
  UploadService? uploadService,
  VoidCallback? onUploadSuccess,
}) {
  final theAppState = appState ?? AppStateNotifier();
  return MaterialApp(
    home: Scaffold(
      body: NotesUploadButton(
        appState: theAppState,
        pickerService: pickerService ?? _FakePickerService(),
        operationManager: OperationManager(
          appState: theAppState,
          uploadService: uploadService ?? _FakeUploadService(events: const []),
        ),
        onUploadSuccess: onUploadSuccess,
      ),
    ),
  );
}

void main() {
  group('NotesUploadButton', () {
    testWidgets('renders Upload Notes button', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Upload Notes'), findsOneWidget);
    });

    testWidgets('no filename shown before picking a file',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      // Only the button text should be present; no extra text widget.
      expect(find.byType(Text).evaluate().where((e) {
        final t = e.widget as Text;
        return t.data != 'Upload Notes';
      }), isEmpty);
    });

    testWidgets('tapping Upload Notes button calls pickerService.pickNotesFile',
        (WidgetTester tester) async {
      final picker = _FakePickerService();
      await tester.pumpWidget(buildSubject(pickerService: picker));

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(picker.callCount, 1);
    });

    testWidgets(
        'when picker returns a path, appState.selectedNotesPath is updated',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final picker = _FakePickerService(returnPath: r'C:\docs\notes.txt');
      await tester.pumpWidget(
          buildSubject(appState: appState, pickerService: picker));

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(appState.selectedNotesPath, r'C:\docs\notes.txt');
    });

    testWidgets('selected filename is displayed after picking a file',
        (WidgetTester tester) async {
      final picker = _FakePickerService(returnPath: r'C:\docs\notes.txt');
      await tester.pumpWidget(buildSubject(pickerService: picker));

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(find.text('notes.txt'), findsOneWidget);
    });

    testWidgets('cancelling picker does not change state',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final picker = _FakePickerService(returnPath: null);
      await tester.pumpWidget(
          buildSubject(appState: appState, pickerService: picker));

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(appState.selectedNotesPath, isNull);
    });

    testWidgets('filename updates when a new file is picked',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\old\campaign.txt');
      final picker = _FakePickerService(returnPath: r'C:\new\session5.txt');
      await tester.pumpWidget(
          buildSubject(appState: appState, pickerService: picker));

      expect(find.text('campaign.txt'), findsOneWidget);

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(find.text('session5.txt'), findsOneWidget);
      expect(find.text('campaign.txt'), findsNothing);
    });

    // Vectorize button tests

    testWidgets('Vectorize button is not shown before a file is picked',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Vectorize'), findsNothing);
    });

    testWidgets('Vectorize button appears after a file is picked',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      await tester.pumpWidget(buildSubject(appState: appState));

      expect(find.text('Vectorize'), findsOneWidget);
    });

    testWidgets('tapping Vectorize calls uploadService.uploadNotes with path',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(uploadService.capturedPath, r'C:\notes.txt');
    });

    testWidgets('LinearProgressIndicator shown while upload is in progress',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _BlockingUploadService();
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      uploadService.controller.close();
      await tester.pumpAndSettle();
    });

    testWidgets('LinearProgressIndicator not shown before upload starts',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      await tester.pumpWidget(buildSubject(appState: appState));

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Vectorize button hidden while upload is in progress',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _BlockingUploadService();
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pump();

      expect(find.text('Vectorize'), findsNothing);

      uploadService.controller.close();
      await tester.pumpAndSettle();
    });

    testWidgets('Upload Notes button is disabled while upload is in progress',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _BlockingUploadService();
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Upload Notes'));
      expect(button.onPressed, isNull);

      uploadService.controller.close();
      await tester.pumpAndSettle();
    });

    testWidgets('success message shown after upload completes',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService =
          _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('Vectorization complete'), findsOneWidget);
    });

    testWidgets('error message shown when upload errors',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(
          events: [UploadErrorEvent(message: 'File not found')]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('File not found'), findsOneWidget);
    });

    testWidgets('Vectorize button reappears after upload error',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(
          events: [UploadErrorEvent(message: 'File not found')]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('Vectorize'), findsOneWidget);
    });

    testWidgets('progress value reflects UploadProgressEvent',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final customService = _FakeUploadService(
          events: [UploadProgressEvent(progress: 75, message: '75%')]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: customService));

      await tester.tap(find.text('Vectorize'));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.value, isNotNull);
    });

    // Re-upload (Issue 20) tests

    testWidgets('Upload Notes button is re-enabled after a successful upload',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      // After a successful upload hasNotes=true so label is 'Re-upload Notes'
      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Re-upload Notes'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Vectorize button remains shown after a successful upload',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.text('Vectorize'), findsOneWidget);
    });

    testWidgets('re-vectorizing after success clears previous success message',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');

      final firstAppState = AppStateNotifier();
      firstAppState.setSelectedNotesPath(r'C:\notes.txt');
      final firstService = _FakeUploadService(events: [UploadDoneEvent()]);

      await tester.pumpWidget(buildSubject(
          appState: firstAppState, uploadService: firstService));
      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();
      expect(find.text('Vectorization complete'), findsOneWidget);

      // New widget tree with blocking service — clears success state
      final blockingService = _BlockingUploadService();
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: blockingService));
      await tester.tap(find.text('Vectorize'));
      await tester.pump();

      expect(find.text('Vectorization complete'), findsNothing);

      blockingService.controller.close();
      await tester.pumpAndSettle();
    });

    testWidgets('re-vectorizing after success calls uploadService again',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');

      int callCount = 0;
      final countingService = _CountingUploadService(
          onCall: () => callCount++, events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: countingService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
    });

    testWidgets(
        'picking a new file resets success state and shows Vectorize button',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\old.txt');
      final uploadService =
          _FakeUploadService(events: [UploadDoneEvent()]);
      final picker = _FakePickerService(returnPath: r'C:\new.txt');
      await tester.pumpWidget(buildSubject(
          appState: appState,
          pickerService: picker,
          uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();
      expect(find.text('Vectorization complete'), findsOneWidget);

      // After first upload hasNotes=true, so button reads 'Re-upload Notes'
      await tester.tap(find.text('Re-upload Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Vectorization complete'), findsNothing);
      expect(find.text('Vectorize'), findsOneWidget);
    });

    testWidgets('shows toast snackbar on successful upload',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Notes uploaded successfully'), findsOneWidget);
    });

    testWidgets('no toast snackbar on upload error',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(
          events: [UploadErrorEvent(message: 'Server error')]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('onUploadSuccess callback is called when upload succeeds',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      var successCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesUploadButton(
            appState: appState,
            pickerService: _FakePickerService(),
            operationManager: OperationManager(
              appState: appState,
              uploadService: uploadService,
            ),
            onUploadSuccess: () => successCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(successCalled, isTrue);
    });

    // Issue 53: label changes with hasNotes flag

    testWidgets('shows Upload Notes when hasNotes is false',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      await tester.pumpWidget(buildSubject(appState: appState));
      expect(find.text('Upload Notes'), findsOneWidget);
      expect(find.text('Re-upload Notes'), findsNothing);
    });

    testWidgets('shows Re-upload Notes when hasNotes is true',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setHasNotes(true);
      await tester.pumpWidget(buildSubject(appState: appState));
      expect(find.text('Re-upload Notes'), findsOneWidget);
      expect(find.text('Upload Notes'), findsNothing);
    });

    testWidgets('sets hasNotes to true on successful upload',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService = _FakeUploadService(events: [UploadDoneEvent()]);
      await tester.pumpWidget(
          buildSubject(appState: appState, uploadService: uploadService));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(appState.hasNotes, isTrue);
    });

    testWidgets('onUploadSuccess callback is NOT called on upload error',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\notes.txt');
      final uploadService =
          _FakeUploadService(events: [UploadErrorEvent(message: 'err')]);
      var successCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesUploadButton(
            appState: appState,
            pickerService: _FakePickerService(),
            operationManager: OperationManager(
              appState: appState,
              uploadService: uploadService,
            ),
            onUploadSuccess: () => successCalled = true,
          ),
        ),
      ));

      await tester.tap(find.text('Vectorize'));
      await tester.pumpAndSettle();

      expect(successCalled, isFalse);
    });
  });
}
