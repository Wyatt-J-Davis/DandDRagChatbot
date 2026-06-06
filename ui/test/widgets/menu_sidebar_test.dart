import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/menu_sidebar.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

void main() {
  group('MenuSidebar', () {
    Widget buildSubject({
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      VoidCallback? onCollapse,
      VoidCallback? onOpenSettings,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              MenuSidebar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected ?? (_) {},
                onCollapse: onCollapse ?? () {},
                onOpenSettings: onOpenSettings ?? () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('builds on a SidebarPanel base', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(SidebarPanel), findsOneWidget);
    });

    testWidgets('shows the three page navigation destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Q&A'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Note Editor'), findsOneWidget);
    });

    testWidgets('shows a Settings entry at the bottom',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows a collapse hamburger button',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byTooltip('Collapse menu'), findsOneWidget);
    });

    testWidgets('tapping a destination reports its index',
        (WidgetTester tester) async {
      int? selected;
      await tester.pumpWidget(
          buildSubject(onDestinationSelected: (i) => selected = i));
      await tester.tap(find.text('Summary'));
      expect(selected, 1);
    });

    testWidgets('tapping the collapse hamburger invokes onCollapse',
        (WidgetTester tester) async {
      var collapsed = false;
      await tester.pumpWidget(buildSubject(onCollapse: () => collapsed = true));
      await tester.tap(find.byTooltip('Collapse menu'));
      expect(collapsed, isTrue);
    });

    testWidgets('tapping Settings invokes onOpenSettings',
        (WidgetTester tester) async {
      var opened = false;
      await tester
          .pumpWidget(buildSubject(onOpenSettings: () => opened = true));
      await tester.tap(find.text('Settings'));
      expect(opened, isTrue);
    });

    testWidgets('highlights the selected destination',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(selectedIndex: 1));
      final selectedTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Summary'),
          matching: find.byType(ListTile),
        ),
      );
      expect(selectedTile.selected, isTrue);
    });
  });
}
