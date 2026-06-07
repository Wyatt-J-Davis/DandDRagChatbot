import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/models/conversation.dart';
import 'package:ttrpg_chatbot/widgets/menu_sidebar.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

Conversation _conv(String id, String title) => Conversation(
      id: id,
      title: title,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

void main() {
  group('MenuSidebar', () {
    Widget buildSubject({
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      VoidCallback? onCollapse,
      VoidCallback? onOpenSettings,
      List<Conversation> conversations = const [],
      String? activeConversationId,
      ValueChanged<String>? onConversationSelected,
      VoidCallback? onNewChat,
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
                conversations: conversations,
                activeConversationId: activeConversationId,
                onConversationSelected: onConversationSelected ?? (_) {},
                onNewChat: onNewChat ?? () {},
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

    group('chat history list', () {
      testWidgets('shows a New chat button', (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        expect(find.text('New chat'), findsOneWidget);
      });

      testWidgets('tapping New chat invokes onNewChat',
          (WidgetTester tester) async {
        var started = false;
        await tester.pumpWidget(buildSubject(onNewChat: () => started = true));
        await tester.tap(find.text('New chat'));
        expect(started, isTrue);
      });

      testWidgets('renders a row per conversation showing its title',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(conversations: [
          _conv('a', 'Who is the villain?'),
          _conv('b', 'Where is the treasure?'),
        ]));
        expect(find.text('Who is the villain?'), findsOneWidget);
        expect(find.text('Where is the treasure?'), findsOneWidget);
      });

      testWidgets('tapping a conversation reports its id',
          (WidgetTester tester) async {
        String? selected;
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'First'), _conv('b', 'Second')],
          onConversationSelected: (id) => selected = id,
        ));
        await tester.tap(find.text('Second'));
        expect(selected, 'b');
      });

      testWidgets('highlights the active conversation',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'First'), _conv('b', 'Second')],
          activeConversationId: 'b',
        ));
        final activeTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text('Second'),
            matching: find.byType(ListTile),
          ),
        );
        final inactiveTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text('First'),
            matching: find.byType(ListTile),
          ),
        );
        expect(activeTile.selected, isTrue);
        expect(inactiveTile.selected, isFalse);
      });
    });
  });
}
