import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/note_editor_page.dart';

Widget buildPage({QuillController? controller}) => MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: Scaffold(body: NoteEditorPage(controller: controller)),
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
  });
}
