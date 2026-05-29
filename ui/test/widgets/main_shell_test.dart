import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';
import 'package:ttrpg_chatbot/services/user_preferences_service.dart';
import 'package:ttrpg_chatbot/services/vectorize_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/main_shell.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';
import 'package:ttrpg_chatbot/widgets/party_member_input.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/services/note_content_service.dart';
import 'package:ttrpg_chatbot/services/status_service.dart';
import 'package:ttrpg_chatbot/widgets/notes_upload_button.dart';
import 'package:ttrpg_chatbot/widgets/temperature_slider.dart';
import 'package:ttrpg_chatbot/widgets/vectorize_button.dart';
import 'package:ttrpg_chatbot/pages/qa_page.dart';
import 'package:ttrpg_chatbot/pages/summary_page.dart';

class _FakePrefsService extends UserPreferencesService {
  UserPreferences _stored;
  final List<UserPreferences> saved = [];

  _FakePrefsService(UserPreferences initial)
      : _stored = initial,
        super(file: File(''));

  @override
  Future<UserPreferences> load() async => _stored;

  @override
  Future<void> save(UserPreferences prefs) async {
    _stored = prefs;
    saved.add(prefs);
  }
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

/// Returns a ModelService whose first call returns an error and whose
/// subsequent calls return [models].
ModelService _stubRetryModelService({required List<String> models}) {
  var callCount = 0;
  return ModelService(
    port: 9999,
    httpClient: MockClient((_) async {
      callCount++;
      if (callCount == 1) {
        return http.Response('Internal Server Error', 500);
      }
      return http.Response(
        '[${models.map((m) => '"$m"').join(',')}]',
        200,
      );
    }),
  );
}


class _FakePickerService extends FilePickerService {
  @override
  Future<String?> pickNotesFile() async => null;
}

class _BlockingUploadService extends UploadService {
  final StreamController<UploadEvent> controller =
      StreamController<UploadEvent>();

  @override
  Stream<UploadEvent> uploadNotes(String _) => controller.stream;
}

class _BlockingVectorizeService extends VectorizeService {
  final StreamController<VectorizeEvent> controller =
      StreamController<VectorizeEvent>();

  @override
  Stream<VectorizeEvent> vectorize(String _) => controller.stream;
}

class _BlockingSummaryService extends SummaryService {
  final StreamController<SummaryEvent> controller =
      StreamController<SummaryEvent>();

  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
  }) =>
      controller.stream;

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _FakeStatusService extends StatusService {
  final bool hasNotes;
  int fetchCount = 0;

  _FakeStatusService({this.hasNotes = false});

  @override
  Future<bool> fetchHasNotes() async {
    fetchCount++;
    return hasNotes;
  }
}

class _FakeNoteContentService extends NoteContentService {
  int fetchCount = 0;
  final String _content;

  _FakeNoteContentService([this._content = '']);

  @override
  Future<String> fetchNotes() async {
    fetchCount++;
    return _content;
  }
}

Widget buildSubject({
  AppStateNotifier? appState,
  ModelService? modelService,
  UserPreferencesService? prefsService,
  FilePickerService? pickerService,
  UploadService? uploadService,
  SummaryService? summaryService,
  VectorizeService? vectorizeService,
  NoteContentService? noteContentService,
  StatusService? statusService,
}) {
  return MaterialApp(
    localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
    supportedLocales: FlutterQuillLocalizations.supportedLocales,
    home: MainShell(
      appState: appState ?? AppStateNotifier(),
      modelService: modelService ?? _stubModelService(),
      prefsService: prefsService,
      pickerService: pickerService ?? _FakePickerService(),
      uploadService: uploadService,
      summaryService: summaryService,
      vectorizeService: vectorizeService,
      noteContentService: noteContentService,
      statusService: statusService,
    ),
  );
}

void main() {
  group('MainShell', () {
    testWidgets(
        'renders a NavigationRail with Q&A, Summary, and Note Editor destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Q&A'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Note Editor'), findsOneWidget);
    });

    testWidgets('shows Q&A page by default', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(); // let model future resolve

      expect(find.byType(QAPage), findsOneWidget);
    });

    testWidgets('tapping Summary destination shows Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(SummaryPage), findsOneWidget);
      expect(find.text('Q&A Page'), findsNothing);
    });

    testWidgets('tapping Note Editor destination shows Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(QuillEditor), findsOneWidget);
      expect(find.text('Q&A Page'), findsNothing);
    });

    testWidgets('tapping back to Q&A shows Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Q&A'));
      await tester.pumpAndSettle();

      expect(find.byType(QAPage), findsOneWidget);
      expect(find.byType(SummaryPage), findsNothing);
    });

    testWidgets('NavigationRail is visible on all pages',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('SidebarPanel is visible inside the shell',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(SidebarPanel), findsOneWidget);
    });

    testWidgets('SidebarPanel is visible on all pages',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(SidebarPanel), findsOneWidget);

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      expect(find.byType(SidebarPanel), findsOneWidget);

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();
      expect(find.byType(SidebarPanel), findsOneWidget);
    });

    testWidgets('SidebarPanel is positioned between NavigationRail and content',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final navRailRect = tester.getRect(find.byType(NavigationRail));
      final sidebarRect = tester.getRect(find.byType(SidebarPanel));
      final contentRight = tester.getRect(find.byType(QAPage)).right;

      expect(sidebarRect.left, greaterThanOrEqualTo(navRailRect.right));
      expect(contentRight, greaterThan(sidebarRect.right));
    });

    testWidgets(
        'ModelSelectorDropdown is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          modelService: _stubModelService(models: ['llama3']),
        ),
      );
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets(
        'ModelSelectorDropdown is not shown in SidebarPanel on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<String>), findsNothing);
    });

    testWidgets('TemperatureSlider is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(TemperatureSlider), findsOneWidget);
    });

    testWidgets('TemperatureSlider is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperatureSlider), findsNothing);
    });

    testWidgets('TemperatureSlider is not shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperatureSlider), findsNothing);
    });

    testWidgets('shows error state then dropdown after tapping Retry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          modelService: _stubRetryModelService(models: ['llama3']),
        ),
      );
      await tester.pumpAndSettle();

      // First fetch fails â€” error message and retry button are shown.
      expect(find.text('No models found. Is Ollama running?'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);

      // Tap Retry â€” second fetch succeeds.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('No models found. Is Ollama running?'), findsNothing);
    });

    testWidgets('loads saved temperature from UserPreferencesService on startup',
        (WidgetTester tester) async {
      final fakePrefs = _FakePrefsService(
        const UserPreferences(model: null, temperature: 0.8),
      );
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(appState: appState, prefsService: fakePrefs),
      );
      await tester.pump();

      expect(appState.temperature, closeTo(0.8, 0.001));
    });

    testWidgets('saves preferences when AppStateNotifier changes',
        (WidgetTester tester) async {
      final fakePrefs = _FakePrefsService(const UserPreferences());
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(appState: appState, prefsService: fakePrefs),
      );
      await tester.pump();

      appState.setTemperature(0.9);

      expect(fakePrefs.saved, isNotEmpty);
      expect(fakePrefs.saved.last.temperature, closeTo(0.9, 0.001));
    });

    testWidgets('PartyMemberInput is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(PartyMemberInput), findsOneWidget);
    });

    testWidgets('PartyMemberInput is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyMemberInput), findsNothing);
    });

    testWidgets('PartyMemberInput is not shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyMemberInput), findsNothing);
    });
    testWidgets('NotesUploadButton is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(NotesUploadButton), findsOneWidget);
    });

    testWidgets('NotesUploadButton is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(NotesUploadButton), findsNothing);
    });

    testWidgets('NotesUploadButton is not shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(NotesUploadButton), findsNothing);
    });

    testWidgets('VectorizeButton is shown in SidebarPanel on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(VectorizeButton), findsOneWidget);
    });

    testWidgets('VectorizeButton is not shown on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(VectorizeButton), findsNothing);
    });

    testWidgets('VectorizeButton is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(VectorizeButton), findsNothing);
    });

    testWidgets('note editor dark mode toggle persists across navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dark mode'));
      await tester.pump();

      await tester.tap(find.text('Q&A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Light mode'), findsOneWidget);
    });

    group('navigation lock during SSE', () {
      testWidgets(
          'destinations are disabled while upload SSE is active',
          (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.setSelectedNotesPath(r'C:\notes.txt');
        final uploadService = _BlockingUploadService();

        await tester.pumpWidget(buildSubject(
          appState: appState,
          uploadService: uploadService,
        ));
        await tester.pump();

        await tester.tap(find.text('Vectorize'));
        await tester.pump();

        await tester.tap(find.text('Summary'));
        await tester.pump();

        expect(find.byType(QAPage), findsOneWidget);

        uploadService.controller.close();
        await tester.pumpAndSettle();
      });

      testWidgets(
          'destinations are re-enabled after upload SSE completes',
          (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.setSelectedNotesPath(r'C:\notes.txt');
        final uploadService = _BlockingUploadService();
        final summaryService = _BlockingSummaryService();

        await tester.pumpWidget(buildSubject(
          appState: appState,
          uploadService: uploadService,
          summaryService: summaryService,
        ));
        await tester.pump();

        await tester.tap(find.text('Vectorize'));
        await tester.pump();

        uploadService.controller.add(UploadDoneEvent());
        await uploadService.controller.close();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        expect(find.byType(SummaryPage), findsOneWidget);
      });

      testWidgets(
          'destinations are disabled while vectorize SSE is active',
          (WidgetTester tester) async {
        final vectorizeService = _BlockingVectorizeService();

        await tester.pumpWidget(buildSubject(
          vectorizeService: vectorizeService,
        ));

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
        await tester.pump();

        await tester.tap(find.text('Q&A'));
        await tester.pump();

        expect(find.byType(QuillEditor), findsOneWidget);

        vectorizeService.controller.close();
        await tester.pumpAndSettle();
      });

      testWidgets(
          'destinations are re-enabled after vectorize SSE completes',
          (WidgetTester tester) async {
        final vectorizeService = _BlockingVectorizeService();

        await tester.pumpWidget(buildSubject(
          vectorizeService: vectorizeService,
        ));

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
        await tester.pump();

        vectorizeService.controller.add(VectorizeDoneEvent());
        await vectorizeService.controller.close();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        expect(find.byType(QAPage), findsOneWidget);
      });

      testWidgets(
          'destinations are disabled while summary generation SSE is active',
          (WidgetTester tester) async {
        final summaryService = _BlockingSummaryService();

        await tester.pumpWidget(buildSubject(
          summaryService: summaryService,
        ));

        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate Summary'));
        await tester.pump();

        await tester.tap(find.text('Q&A'));
        await tester.pump();

        expect(find.byType(SummaryPage), findsOneWidget);

        summaryService.controller.close();
        await tester.pumpAndSettle();
      });

      testWidgets(
          'destinations are re-enabled after summary generation SSE completes',
          (WidgetTester tester) async {
        final summaryService = _BlockingSummaryService();

        await tester.pumpWidget(buildSubject(
          summaryService: summaryService,
        ));

        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate Summary'));
        await tester.pump();

        summaryService.controller.add(SummaryErrorEvent(message: 'err'));
        await summaryService.controller.close();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        expect(find.byType(QAPage), findsOneWidget);
      });
    });

    testWidgets('calls NoteContentService.fetchNotes on startup when service provided',
        (WidgetTester tester) async {
      final service = _FakeNoteContentService('some notes');

      await tester.pumpWidget(buildSubject(noteContentService: service));
      await tester.pump();

      expect(service.fetchCount, 1);
    });

    testWidgets('calls StatusService.fetchHasNotes on startup when service provided',
        (WidgetTester tester) async {
      final statusService = _FakeStatusService(hasNotes: false);

      await tester.pumpWidget(buildSubject(statusService: statusService));
      await tester.pump();

      expect(statusService.fetchCount, 1);
    });

    testWidgets('sets appState.hasNotes true when StatusService reports notes present',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final statusService = _FakeStatusService(hasNotes: true);

      await tester.pumpWidget(buildSubject(
          appState: appState, statusService: statusService));
      await tester.pump();

      expect(appState.hasNotes, isTrue);
    });
  });
}

