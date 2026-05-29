import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/note_editor_page.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/services/note_content_service.dart';
import 'package:ttrpg_chatbot/services/note_export_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';
import 'package:ttrpg_chatbot/widgets/vectorize_button.dart';

class _FakeNoteContentService extends NoteContentService {
  bool saveNotesCalled = false;
  String? lastSavedContent;

  _FakeNoteContentService() : super(port: 9999);

  @override
  Future<bool> saveNotes(String content) async {
    saveNotesCalled = true;
    lastSavedContent = content;
    return true;
  }
}

class _FakeNoteExportService extends NoteExportService {
  bool fetchTxtCalled = false;
  bool fetchDocxCalled = false;

  _FakeNoteExportService() : super(port: 9999);

  @override
  Future<Uint8List?> fetchTxtBytes() async {
    fetchTxtCalled = true;
    return Uint8List.fromList([116, 120, 116]);
  }

  @override
  Future<Uint8List?> fetchDocxBytes() async {
    fetchDocxCalled = true;
    return Uint8List.fromList([80, 75, 3, 4]);
  }
}

class _FakeFilePickerService extends FilePickerService {
  String? returnPath;
  String? capturedFileName;

  _FakeFilePickerService({this.returnPath});

  @override
  Future<String?> pickSavePath({required String fileName}) async {
    capturedFileName = fileName;
    return returnPath;
  }
}

Widget buildPage({
  QuillController? controller,
  bool darkMode = false,
  VoidCallback? onToggleDarkMode,
  OperationManager? operationManager,
  NoteContentService? noteContentService,
  NoteExportService? noteExportService,
  FilePickerService? filePickerService,
}) =>
    MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: Scaffold(
        body: NoteEditorPage(
          controller: controller,
          darkMode: darkMode,
          onToggleDarkMode: onToggleDarkMode,
          operationManager: operationManager,
          noteContentService: noteContentService,
          noteExportService: noteExportService,
          filePickerService: filePickerService,
        ),
      ),
    );

void main() {
  group('NoteEditorPage', () {
    testWidgets('renders QuillEditor', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('renders QuillSimpleToolbar', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    });

    testWidgets('toolbar shows Bold button', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bold'), findsOneWidget);
    });

    testWidgets('toolbar shows Italic button', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Italic'), findsOneWidget);
    });

    testWidgets('toolbar shows Numbered List button', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Numbered list'), findsOneWidget);
    });

    testWidgets('toolbar shows Bullet List button', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bullet list'), findsOneWidget);
    });

    testWidgets('toolbar shows header style control', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(find.byType(QuillToolbarSelectHeaderStyleDropdownButton),
          findsOneWidget);
    });

    testWidgets('tapping Bold toggles bold in controller', (tester) async {
      final controller = QuillController.basic();
      await tester.pumpWidget(buildPage(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bold'));
      await tester.pump();
      expect(
        controller
            .getSelectionStyle()
            .attributes
            .containsKey(Attribute.bold.key),
        isTrue,
      );
    });

    group('dark mode toggle', () {
      testWidgets('dark mode toggle button is visible', (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
        expect(find.byTooltip('Dark mode'), findsOneWidget);
      });

      testWidgets('tapping toggle calls onToggleDarkMode', (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildPage(onToggleDarkMode: () => called = true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Dark mode'));
        await tester.pump();
        expect(called, isTrue);
      });

      testWidgets('darkMode: false renders light background', (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('editor_background')),
        );
        expect(container.color, Colors.white);
      });

      testWidgets('darkMode: true renders dark background', (tester) async {
        await tester.pumpWidget(buildPage(darkMode: true));
        await tester.pumpAndSettle();
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('editor_background')),
        );
        expect(container.color, const Color(0xFF1E1E1E));
      });

      testWidgets('darkMode defaults to false — shows dark_mode icon',
          (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.dark_mode), findsOneWidget);
        expect(find.byIcon(Icons.light_mode), findsNothing);
      });

      testWidgets('darkMode: true shows light_mode icon', (tester) async {
        await tester.pumpWidget(buildPage(darkMode: true));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.light_mode), findsOneWidget);
        expect(find.byIcon(Icons.dark_mode), findsNothing);
      });
    });

    group('VectorizeButton', () {
      testWidgets('shown when operationManager is provided', (tester) async {
        final appState = AppStateNotifier();
        final om = OperationManager(appState: appState);
        await tester.pumpWidget(buildPage(operationManager: om));
        await tester.pumpAndSettle();
        expect(find.byType(VectorizeButton), findsOneWidget);
      });

      testWidgets('not shown when operationManager is null (default)',
          (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
        expect(find.byType(VectorizeButton), findsNothing);
      });

      testWidgets('is in the header row when operationManager is provided',
          (tester) async {
        final appState = AppStateNotifier();
        final om = OperationManager(appState: appState);
        await tester.pumpWidget(buildPage(operationManager: om));
        await tester.pumpAndSettle();

        final headerRow = find.byKey(const ValueKey('header_row'));
        expect(headerRow, findsOneWidget);
        expect(
          find.descendant(
              of: headerRow, matching: find.byType(VectorizeButton)),
          findsOneWidget,
        );
      });

      testWidgets('is not in the header row when operationManager is null',
          (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        final headerRow = find.byKey(const ValueKey('header_row'));
        expect(headerRow, findsOneWidget);
        expect(
          find.descendant(
              of: headerRow, matching: find.byType(VectorizeButton)),
          findsNothing,
        );
      });
    });

    group('export buttons', () {
      testWidgets(
          'Export .txt and Export .docx buttons shown when all export services provided',
          (tester) async {
        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: _FakeNoteExportService(),
          filePickerService: _FakeFilePickerService(returnPath: null),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Export .txt'), findsOneWidget);
        expect(find.text('Export .docx'), findsOneWidget);
      });

      testWidgets('export buttons not shown when services are null (default)',
          (tester) async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
        expect(find.text('Export .txt'), findsNothing);
        expect(find.text('Export .docx'), findsNothing);
      });

      testWidgets('tapping Export .txt calls saveNotes with editor content',
          (tester) async {
        final controller = QuillController.basic();
        final contentService = _FakeNoteContentService();
        final exportService = _FakeNoteExportService();
        final pickerService =
            _FakeFilePickerService(returnPath: r'C:\tmp\notes.txt');

        await tester.pumpWidget(buildPage(
          controller: controller,
          noteContentService: contentService,
          noteExportService: exportService,
          filePickerService: pickerService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .txt'));
        await tester.pumpAndSettle();

        expect(contentService.saveNotesCalled, isTrue);
      });

      testWidgets('tapping Export .txt fetches txt bytes', (tester) async {
        final exportService = _FakeNoteExportService();
        final pickerService =
            _FakeFilePickerService(returnPath: r'C:\tmp\notes.txt');

        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: exportService,
          filePickerService: pickerService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .txt'));
        await tester.pumpAndSettle();

        expect(exportService.fetchTxtCalled, isTrue);
        expect(exportService.fetchDocxCalled, isFalse);
      });

      testWidgets('tapping Export .docx fetches docx bytes', (tester) async {
        final exportService = _FakeNoteExportService();
        final pickerService =
            _FakeFilePickerService(returnPath: r'C:\tmp\notes.docx');

        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: exportService,
          filePickerService: pickerService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .docx'));
        await tester.pumpAndSettle();

        expect(exportService.fetchDocxCalled, isTrue);
        expect(exportService.fetchTxtCalled, isFalse);
      });

      testWidgets(
          'tapping Export .txt passes notes.txt as default file name to picker',
          (tester) async {
        final pickerService =
            _FakeFilePickerService(returnPath: null);

        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: _FakeNoteExportService(),
          filePickerService: pickerService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .txt'));
        await tester.pumpAndSettle();

        expect(pickerService.capturedFileName, 'notes.txt');
      });

      testWidgets(
          'tapping Export .docx passes notes.docx as default file name to picker',
          (tester) async {
        final pickerService =
            _FakeFilePickerService(returnPath: null);

        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: _FakeNoteExportService(),
          filePickerService: pickerService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .docx'));
        await tester.pumpAndSettle();

        expect(pickerService.capturedFileName, 'notes.docx');
      });

      testWidgets('does not fetch bytes when picker returns null',
          (tester) async {
        final exportService = _FakeNoteExportService();

        await tester.pumpWidget(buildPage(
          noteContentService: _FakeNoteContentService(),
          noteExportService: exportService,
          filePickerService: _FakeFilePickerService(returnPath: null),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export .txt'));
        await tester.pumpAndSettle();

        expect(exportService.fetchTxtCalled, isFalse);
      });
    });
  });
}
