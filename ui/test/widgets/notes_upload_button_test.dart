import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/file_picker_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
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

Widget buildSubject({
  AppStateNotifier? appState,
  FilePickerService? pickerService,
}) {
  return MaterialApp(
    home: Scaffold(
      body: NotesUploadButton(
        appState: appState ?? AppStateNotifier(),
        pickerService: pickerService ?? _FakePickerService(),
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

    testWidgets('when picker returns a path, appState.selectedNotesPath is updated',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      final picker = _FakePickerService(returnPath: r'C:\docs\notes.txt');
      await tester.pumpWidget(buildSubject(appState: appState, pickerService: picker));

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
      await tester.pumpWidget(buildSubject(appState: appState, pickerService: picker));

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(appState.selectedNotesPath, isNull);
    });

    testWidgets('filename updates when a new file is picked',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setSelectedNotesPath(r'C:\old\campaign.txt');
      final picker = _FakePickerService(returnPath: r'C:\new\session5.txt');
      await tester.pumpWidget(buildSubject(appState: appState, pickerService: picker));

      expect(find.text('campaign.txt'), findsOneWidget);

      await tester.tap(find.text('Upload Notes'));
      await tester.pump();

      expect(find.text('session5.txt'), findsOneWidget);
      expect(find.text('campaign.txt'), findsNothing);
    });
  });
}
