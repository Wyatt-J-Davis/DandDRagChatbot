import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/main_shell.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

void main() {
  group('MainShell', () {
    Widget buildSubject() => const MaterialApp(home: MainShell());

    testWidgets('renders a NavigationRail with Q&A, Summary, and Note Editor destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Q&A'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Note Editor'), findsOneWidget);
    });

    testWidgets('shows Q&A page stub by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Q&A Page'), findsOneWidget);
    });

    testWidgets('tapping Summary destination shows Summary page stub',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Summary Page'), findsOneWidget);
      expect(find.text('Q&A Page'), findsNothing);
    });

    testWidgets('tapping Note Editor destination shows Note Editor page stub',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.text('Note Editor Page'), findsOneWidget);
      expect(find.text('Q&A Page'), findsNothing);
    });

    testWidgets('tapping back to Q&A shows Q&A page stub',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Q&A'));
      await tester.pumpAndSettle();

      expect(find.text('Q&A Page'), findsOneWidget);
      expect(find.text('Summary Page'), findsNothing);
    });

    testWidgets('NavigationRail is visible on all pages',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      // On Q&A page
      expect(find.byType(NavigationRail), findsOneWidget);

      // On Summary page
      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

      // On Note Editor page
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

      final navRailRect = tester.getRect(find.byType(NavigationRail));
      final sidebarRect = tester.getRect(find.byType(SidebarPanel));
      final contentRight = tester.getRect(find.text('Q&A Page')).right;

      // Sidebar starts at or after the right edge of the rail
      expect(sidebarRect.left, greaterThanOrEqualTo(navRailRect.right));
      // Content starts at or after the right edge of the sidebar
      expect(contentRight, greaterThan(sidebarRect.right));
    });
  });
}
