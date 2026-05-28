import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/pages/note_editor_page.dart';

Widget buildPage({
  QuillController? controller,
  bool darkMode = false,
  VoidCallback? onToggleDarkMode,
}) =>
    MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: Scaffold(
        body: NoteEditorPage(
          controller: controller,
          darkMode: darkMode,
          onToggleDarkMode: onToggleDarkMode,
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
  });
}
