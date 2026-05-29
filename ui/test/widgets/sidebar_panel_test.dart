import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

void main() {
  group('SidebarPanel', () {
    Widget buildSubject({ColorScheme? colorScheme}) {
      final cs = colorScheme ??
          ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );
      return MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: cs),
        home: const Scaffold(body: Row(children: [SidebarPanel()])),
      );
    }

    testWidgets('renders with a fixed width of 240', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      final size = tester.getSize(find.byType(SidebarPanel));
      expect(size.width, 240.0);
    });

    testWidgets('background matches surfaceContainerLow from theme',
        (WidgetTester tester) async {
      final cs = ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      );
      await tester.pumpWidget(buildSubject(colorScheme: cs));

      expect(
        find.byWidgetPredicate(
          (w) => w is Material && w.color == cs.surfaceContainerLow,
        ),
        findsOneWidget,
      );
    });
  });
}
