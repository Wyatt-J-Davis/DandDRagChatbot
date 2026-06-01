import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';
import 'package:ttrpg_chatbot/services/party_service.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';
import 'package:ttrpg_chatbot/services/user_preferences_service.dart';
import 'package:ttrpg_chatbot/services/vectorize_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/main_shell.dart';
import 'package:ttrpg_chatbot/widgets/settings_popup.dart';
import 'package:ttrpg_chatbot/widgets/vectorize_button.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/services/note_content_service.dart';
import 'package:ttrpg_chatbot/services/status_service.dart';
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

/// Prefs service that does not complete until [complete] is called.
class _SlowPrefsService extends UserPreferencesService {
  final _completer = Completer<UserPreferences>();

  _SlowPrefsService() : super(file: File(''));

  @override
  Future<UserPreferences> load() => _completer.future;

  @override
  Future<void> save(UserPreferences prefs) async {}

  void complete({double scrollOffset = 0.0}) =>
      _completer.complete(UserPreferences(scrollOffset: scrollOffset));
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
    required double temperature,
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

class _FakePartyService extends PartyService {
  int fetchCount = 0;
  final List<String> _members;
  final String? _noteTaker;

  _FakePartyService([this._members = const [], this._noteTaker]);

  @override
  Future<({List<String> members, String? noteTaker})> fetchPartyMembers() async {
    fetchCount++;
    return (members: List<String>.from(_members), noteTaker: _noteTaker);
  }
}

class _AnswerChatService extends ChatService {
  final String answer;
  _AnswerChatService([this.answer = 'The answer']);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: answer, sources: []);
  }
}

Widget buildSubject({
  AppStateNotifier? appState,
  ModelService? modelService,
  UserPreferencesService? prefsService,
  FilePickerService? pickerService,
  UploadService? uploadService,
  ChatService? chatService,
  SummaryService? summaryService,
  VectorizeService? vectorizeService,
  NoteContentService? noteContentService,
  StatusService? statusService,
  PartyService? partyService,
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
      chatService: chatService,
      summaryService: summaryService,
      vectorizeService: vectorizeService,
      noteContentService: noteContentService,
      statusService: statusService,
      partyService: partyService,
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

    group('navigation icons', () {
      testWidgets('Q&A destination uses orb-style icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byIcon(Icons.lens), findsAtLeast(1));
      });

      testWidgets('Summary destination uses auto_awesome icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byIcon(Icons.auto_awesome), findsAtLeast(1));
      });

      testWidgets('Note Editor destination uses history_edu icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byIcon(Icons.history_edu), findsAtLeast(1));
      });
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

    group('settings icon', () {
      testWidgets('settings icon is visible in NavigationRail',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byTooltip('Settings'), findsOneWidget);
      });

      testWidgets('settings icon is visible on all three pages',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.byTooltip('Settings'), findsOneWidget);

        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Settings'), findsOneWidget);

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Settings'), findsOneWidget);
      });

      testWidgets('tapping settings icon opens SettingsPopup dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
          modelService: _stubModelService(models: ['llama3']),
        ));
        await tester.pump();

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsPopup), findsOneWidget);
      });
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

    testWidgets('VectorizeButton is shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(VectorizeButton), findsOneWidget);
    });

    group('operations survive page switches', () {
      testWidgets(
          'navigation is allowed while upload SSE is active',
          (WidgetTester tester) async {
        final appState = AppStateNotifier();
        appState.setSelectedNotesPath(r'C:\notes.txt');
        final uploadService = _BlockingUploadService();

        await tester.pumpWidget(buildSubject(
          appState: appState,
          uploadService: uploadService,
        ));
        await tester.pump();

        // Open settings and start upload via Vectorize button
        await tester.tap(find.byTooltip('Settings'));
        await tester.pump();

        await tester.ensureVisible(find.text('Vectorize'));
        await tester.tap(find.text('Vectorize'), warnIfMissed: false);
        await tester.pump();

        // Close the dialog
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        // Navigation must succeed while upload is in progress
        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        expect(find.byType(SummaryPage), findsOneWidget);

        uploadService.controller.close();
        await tester.pump();
      });

      testWidgets(
          'navigation is allowed while vectorize SSE is active',
          (WidgetTester tester) async {
        final vectorizeService = _BlockingVectorizeService();

        await tester.pumpWidget(buildSubject(
          vectorizeService: vectorizeService,
        ));

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Vectorize'));
        await tester.pump();

        // Navigation must succeed while vectorize is in progress
        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        expect(find.byType(QAPage), findsOneWidget);

        vectorizeService.controller.close();
        await tester.pump();
      });

      testWidgets(
          'navigation is allowed while summary generation SSE is active',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final summaryService = _BlockingSummaryService();

        await tester.pumpWidget(buildSubject(
          summaryService: summaryService,
        ));

        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate Summary'));
        await tester.pump();

        // Navigation must succeed while summary generation is in progress
        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        expect(find.byType(QAPage), findsOneWidget);

        summaryService.controller.close();
        await tester.pumpAndSettle();
      });

      testWidgets('chat history persists after navigating away and back',
          (WidgetTester tester) async {
        final appState = AppStateNotifier();
        final chatService = _AnswerChatService('The dragon is red.');

        await tester.pumpWidget(buildSubject(
          appState: appState,
          chatService: chatService,
        ));
        await tester.pump();

        // The Q&A page has the only text field on screen (sidebar removed)
        await tester.enterText(find.byType(TextField), 'What is the dragon?');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        // 500ms per pump covers the 18-char typewriter (18×20ms=360ms)
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(find.text('What is the dragon?'), findsOneWidget);
        expect(find.text('The dragon is red.'), findsOneWidget);

        // Navigate away and back
        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        // History must still be present
        expect(find.text('What is the dragon?'), findsOneWidget);
        expect(find.text('The dragon is red.'), findsOneWidget);
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

    testWidgets('calls PartyService.fetchPartyMembers on startup when service provided',
        (WidgetTester tester) async {
      final partyService = _FakePartyService();

      await tester.pumpWidget(buildSubject(partyService: partyService));
      await tester.pump();

      expect(partyService.fetchCount, 1);
    });

    testWidgets('sets appState.partyMembers from PartyService response',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final partyService = _FakePartyService(['Aria', 'Borin']);

      await tester.pumpWidget(buildSubject(
          appState: appState, partyService: partyService));
      await tester.pump();

      expect(appState.partyMembers, ['Aria', 'Borin']);
    });

    testWidgets('restores noteTaker from PartyService response on startup',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final partyService = _FakePartyService(['Aria', 'Borin'], 'Borin');

      await tester.pumpWidget(buildSubject(
          appState: appState, partyService: partyService));
      await tester.pump();

      expect(appState.noteTaker, 'Borin');
    });

    testWidgets('leaves noteTaker unset when PartyService returns null noteTaker',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final partyService = _FakePartyService(['Aria', 'Borin']);

      await tester.pumpWidget(buildSubject(
          appState: appState, partyService: partyService));
      await tester.pump();

      expect(appState.noteTaker, isNull);
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

    testWidgets('restores darkMode from UserPreferencesService on startup',
        (WidgetTester tester) async {
      final fakePrefs = _FakePrefsService(
        const UserPreferences(darkMode: true),
      );

      await tester.pumpWidget(buildSubject(prefsService: fakePrefs));
      await tester.pump();

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Light mode'), findsOneWidget);
    });

    group('scroll position persistence', () {
      testWidgets(
          'notes fetch does not start until prefsService.load() resolves',
          (WidgetTester tester) async {
        final prefs = _SlowPrefsService();
        final notes = _FakeNoteContentService('some content');

        await tester.pumpWidget(buildSubject(
          prefsService: prefs,
          noteContentService: notes,
        ));
        await tester.pump();

        // Prefs are still pending — notes must not have been fetched yet.
        expect(notes.fetchCount, 0);
      });

      testWidgets(
          'fetchNotes is called exactly once after prefsService resolves',
          (WidgetTester tester) async {
        final prefs = _SlowPrefsService();
        final notes = _FakeNoteContentService('some content');

        await tester.pumpWidget(buildSubject(
          prefsService: prefs,
          noteContentService: notes,
        ));
        await tester.pump();

        prefs.complete();
        await tester.pumpAndSettle();

        expect(notes.fetchCount, 1);
      });

      testWidgets(
          'navigating back to Note Editor tab does not crash when stored offset is nonzero',
          (WidgetTester tester) async {
        final prefs = _FakePrefsService(
          const UserPreferences(scrollOffset: 50.0),
        );
        final notes = _FakeNoteContentService('some content');

        await tester.pumpWidget(buildSubject(
          prefsService: prefs,
          noteContentService: notes,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        expect(find.byType(QuillEditor), findsOneWidget);
      });

      testWidgets(
          'scroll restore is not attempted when stored offset is zero',
          (WidgetTester tester) async {
        final prefs = _FakePrefsService(const UserPreferences(scrollOffset: 0.0));
        final notes = _FakeNoteContentService('some content');

        await tester.pumpWidget(buildSubject(
          prefsService: prefs,
          noteContentService: notes,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Q&A'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note Editor'));
        await tester.pumpAndSettle();

        // No crash; editor is present.
        expect(find.byType(QuillEditor), findsOneWidget);
      });
    });
  });
}
