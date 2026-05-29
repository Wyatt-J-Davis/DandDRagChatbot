import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';
import 'package:ttrpg_chatbot/widgets/settings_popup.dart';

class _FakePickerService extends FilePickerService {
  final String? returnPath;
  _FakePickerService({this.returnPath});

  @override
  Future<String?> pickNotesFile() async => returnPath;
}

class _FakeUploadService extends UploadService {
  final List<UploadEvent> events;
  _FakeUploadService({required this.events});

  @override
  Stream<UploadEvent> uploadNotes(String _) async* {
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

ModelService _stubModelService({List<String> models = const []}) {
  return ModelService(
    port: 9999,
    httpClient: MockClient(
      (_) async => http.Response(
        '[${models.map((m) => '"$m"').join(',')}]',
        200,
      ),
    ),
  );
}

Widget buildSubject({
  AppStateNotifier? appState,
  OperationManager? operationManager,
  Future<List<String>>? modelsFuture,
  FilePickerService? pickerService,
  VoidCallback? onModelRetry,
  VoidCallback? onUploadSuccess,
  UploadService? uploadService,
}) {
  final theAppState = appState ?? AppStateNotifier();
  final om = operationManager ??
      OperationManager(
        appState: theAppState,
        uploadService: uploadService,
      );
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SettingsPopup(
          appState: theAppState,
          operationManager: om,
          modelsFuture: modelsFuture ?? Future.value([]),
          onModelRetry: onModelRetry ?? () {},
          pickerService: pickerService ?? _FakePickerService(),
          onUploadSuccess: onUploadSuccess,
        ),
      ),
    ),
  );
}

void main() {
  group('SettingsPopup', () {
    group('section labels', () {
      testWidgets('renders Model section label', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Model'), findsOneWidget);
      });

      testWidgets('renders Temperature section label', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Temperature'), findsOneWidget);
      });

      testWidgets('renders Party Members section label', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Party Members'), findsOneWidget);
      });

      testWidgets('renders Note Taker section label', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Note Taker'), findsOneWidget);
      });

      testWidgets('renders Notes section label', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('Notes'), findsOneWidget);
      });
    });

    group('Note Taker section', () {
      testWidgets('shows helper text', (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(
          find.text('Whose perspective the AI answers from'),
          findsOneWidget,
        );
      });

      testWidgets('shows party members as radio options', (tester) async {
        final appState = AppStateNotifier();
        appState.addPartyMember('Aria');
        appState.addPartyMember('Borin');

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.text('Aria'), findsOneWidget);
        expect(find.text('Borin'), findsOneWidget);
        expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      });

      testWidgets('tapping a radio sets note taker', (tester) async {
        final appState = AppStateNotifier();
        appState.addPartyMember('Aria');

        await tester.pumpWidget(buildSubject(appState: appState));

        await tester.tap(find.byType(RadioListTile<String>).first);
        await tester.pump();

        expect(appState.noteTaker, 'Aria');
      });

      testWidgets('delete button removes party member', (tester) async {
        final appState = AppStateNotifier();
        appState.addPartyMember('Aria');

        await tester.pumpWidget(buildSubject(appState: appState));

        await tester.tap(find.byIcon(Icons.delete));
        await tester.pump();

        expect(appState.partyMembers, isEmpty);
        expect(find.text('Aria'), findsNothing);
      });
    });

    group('Temperature section', () {
      testWidgets('shows current temperature value', (tester) async {
        final appState = AppStateNotifier();
        appState.setTemperature(0.7);

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.text('0.7'), findsOneWidget);
      });

      testWidgets('slider changes temperature', (tester) async {
        final appState = AppStateNotifier();
        appState.setTemperature(0.5);

        await tester.pumpWidget(buildSubject(appState: appState));

        await tester.drag(find.byType(Slider), const Offset(50, 0));
        await tester.pump();

        expect(appState.temperature, isNot(closeTo(0.5, 0.01)));
      });
    });

    group('Party Members section', () {
      testWidgets('shows text field and Add button', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(TextField), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
      });

      testWidgets('typing and tapping Add adds a party member', (tester) async {
        final appState = AppStateNotifier();

        await tester.pumpWidget(buildSubject(appState: appState));

        await tester.enterText(find.byType(TextField), 'Gandalf');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
        await tester.pump();

        expect(appState.partyMembers, contains('Gandalf'));
      });

      testWidgets('text field is cleared after adding a member', (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextField), 'Gimli');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
        await tester.pump();

        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.controller?.text ?? '', isEmpty);
      });
    });

    group('Notes section', () {
      testWidgets('shows Upload Notes when hasNotes is false', (tester) async {
        final appState = AppStateNotifier();

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.widgetWithText(ElevatedButton, 'Upload Notes'),
            findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Re-upload Notes'),
            findsNothing);
      });

      testWidgets('shows Re-upload Notes when hasNotes is true', (tester) async {
        final appState = AppStateNotifier();
        appState.setHasNotes(true);

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.widgetWithText(ElevatedButton, 'Re-upload Notes'),
            findsOneWidget);
        expect(
            find.widgetWithText(ElevatedButton, 'Upload Notes'), findsNothing);
      });

      testWidgets('shows No notes loaded when hasNotes is false',
          (tester) async {
        final appState = AppStateNotifier();

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.text('No notes loaded'), findsOneWidget);
        expect(find.text('Notes loaded'), findsNothing);
      });

      testWidgets('shows Notes loaded when hasNotes is true', (tester) async {
        final appState = AppStateNotifier();
        appState.setHasNotes(true);

        await tester.pumpWidget(buildSubject(appState: appState));

        expect(find.text('Notes loaded'), findsOneWidget);
        expect(find.text('No notes loaded'), findsNothing);
      });

      testWidgets('shows Lottie widget while upload is in progress',
          (tester) async {
        final appState = AppStateNotifier();
        appState.setSelectedNotesPath(r'C:\notes.txt');
        final uploadService = _BlockingUploadService();

        await tester.pumpWidget(
            buildSubject(appState: appState, uploadService: uploadService));

        await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
        await tester.pump();

        expect(find.byType(Lottie), findsOneWidget);

        uploadService.controller.close();
        await tester.pump();
      });

      testWidgets('shows LinearProgressIndicator while upload is in progress',
          (tester) async {
        final appState = AppStateNotifier();
        appState.setSelectedNotesPath(r'C:\notes.txt');
        final uploadService = _BlockingUploadService();

        await tester.pumpWidget(
            buildSubject(appState: appState, uploadService: uploadService));

        await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        uploadService.controller.close();
        await tester.pump();
      });
    });

    group('Model section', () {
      testWidgets('shows dropdown when models are available', (tester) async {
        final modelsFuture =
            _stubModelService(models: ['llama3']).fetchModels();

        await tester.pumpWidget(
            buildSubject(modelsFuture: modelsFuture));
        await tester.pumpAndSettle();

        expect(find.byType(DropdownButton<String>), findsOneWidget);
      });

      testWidgets('shows error when no models found', (tester) async {
        final modelsFuture = _stubModelService(models: []).fetchModels();

        await tester.pumpWidget(
            buildSubject(modelsFuture: modelsFuture));
        await tester.pumpAndSettle();

        expect(find.text('No models found. Is Ollama running?'), findsOneWidget);
      });
    });
  });
}
