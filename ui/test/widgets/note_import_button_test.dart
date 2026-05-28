import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/note_file_reader_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/note_import_button.dart';

class _FakeFileReader extends NoteFileReaderService {
  final String content;
  const _FakeFileReader(this.content);

  @override
  Future<String> readFile(String path) async => content;
}

class _FailingFileReader extends NoteFileReaderService {
  const _FailingFileReader();

  @override
  Future<String> readFile(String path) => Future.error('read error');
}

void main() {
  late AppStateNotifier appState;
  late QuillController controller;

  setUp(() {
    appState = AppStateNotifier();
    controller = QuillController.basic();
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildSubject({NoteFileReaderService? fileReader}) => MaterialApp(
        localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: Scaffold(
          body: NoteImportButton(
            controller: controller,
            appState: appState,
            fileReader: fileReader,
          ),
        ),
      );

  group('NoteImportButton', () {
    testWidgets('Import button is visible', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('button is disabled when no file uploaded', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('disabled button has tooltip when no file uploaded',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byTooltip('No notes file uploaded'), findsOneWidget);
    });

    testWidgets('button is enabled when file is uploaded', (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping import with empty editor loads content without dialog',
        (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      await tester.pumpWidget(
          buildSubject(fileReader: const _FakeFileReader('Campaign notes')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.document.toPlainText().trim(), 'Campaign notes');
    });

    testWidgets(
        'tapping import with non-empty editor shows confirmation dialog',
        (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      controller.replaceText(
          0, 0, 'Existing content', const TextSelection.collapsed(offset: 0));
      await tester.pumpWidget(
          buildSubject(fileReader: const _FakeFileReader('New content')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('confirming dialog replaces editor content', (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      controller.replaceText(
          0, 0, 'Existing content', const TextSelection.collapsed(offset: 0));
      await tester.pumpWidget(
          buildSubject(fileReader: const _FakeFileReader('New content')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(controller.document.toPlainText().trim(), 'New content');
    });

    testWidgets('canceling dialog does not replace editor content',
        (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      controller.replaceText(
          0, 0, 'Existing content', const TextSelection.collapsed(offset: 0));
      await tester.pumpWidget(
          buildSubject(fileReader: const _FakeFileReader('New content')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.document.toPlainText().trim(), 'Existing content');
    });

    testWidgets('file read failure shows error snackbar', (tester) async {
      appState.setSelectedNotesPath('/path/to/notes.txt');
      await tester.pumpWidget(
          buildSubject(fileReader: const _FailingFileReader()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to read file.'), findsOneWidget);
    });
  });
}
