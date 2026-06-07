import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/models/conversation.dart';
import 'package:ttrpg_chatbot/widgets/menu_sidebar.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

Conversation _conv(String id, String title, {bool archived = false}) =>
    Conversation(
      id: id,
      title: title,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      archived: archived,
    );

/// Moves a synthetic mouse pointer over [finder] so hover-revealed controls
/// become visible.
Future<void> _hoverOver(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
}

void main() {
  group('MenuSidebar', () {
    Widget buildSubject({
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      VoidCallback? onCollapse,
      VoidCallback? onOpenSettings,
      List<Conversation> conversations = const [],
      List<Conversation> archivedConversations = const [],
      String? activeConversationId,
      ValueChanged<String>? onConversationSelected,
      VoidCallback? onNewChat,
      ValueChanged<String>? onRenameConversation,
      ValueChanged<String>? onArchiveConversation,
      ValueChanged<String>? onDeleteConversation,
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
                archivedConversations: archivedConversations,
                activeConversationId: activeConversationId,
                onConversationSelected: onConversationSelected ?? (_) {},
                onNewChat: onNewChat ?? () {},
                onRenameConversation: onRenameConversation ?? (_) {},
                onArchiveConversation: onArchiveConversation ?? (_) {},
                onDeleteConversation: onDeleteConversation ?? (_) {},
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

    group('conversation management', () {
      testWidgets('overflow menu is hidden until the row is hovered',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(conversations: [
          _conv('a', 'First'),
        ]));
        expect(find.byIcon(Icons.more_vert), findsNothing);

        await _hoverOver(tester, find.text('First'));
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });

      testWidgets('overflow menu offers Rename, Archive, and Delete',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(conversations: [
          _conv('a', 'First'),
        ]));
        await _hoverOver(tester, find.text('First'));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Archive'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('selecting Rename reports the conversation id',
          (WidgetTester tester) async {
        String? renamed;
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'First')],
          onRenameConversation: (id) => renamed = id,
        ));
        await _hoverOver(tester, find.text('First'));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        expect(renamed, 'a');
      });

      testWidgets('selecting Archive reports the conversation id',
          (WidgetTester tester) async {
        String? archived;
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'First')],
          onArchiveConversation: (id) => archived = id,
        ));
        await _hoverOver(tester, find.text('First'));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(archived, 'a');
      });

      testWidgets('selecting Delete reports the conversation id',
          (WidgetTester tester) async {
        String? deleted;
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'First')],
          onDeleteConversation: (id) => deleted = id,
        ));
        await _hoverOver(tester, find.text('First'));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(deleted, 'a');
      });

      testWidgets('archived rows offer Unarchive instead of Archive',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
          archivedConversations: [_conv('a', 'Old chat', archived: true)],
        ));
        // Expand the Archived section first.
        await tester.tap(find.text('Archived'));
        await tester.pumpAndSettle();

        await _hoverOver(tester, find.text('Old chat'));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Unarchive'), findsOneWidget);
        expect(find.text('Archive'), findsNothing);
      });

      testWidgets('no Archived section when there are no archived conversations',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(conversations: [
          _conv('a', 'First'),
        ]));
        expect(find.text('Archived'), findsNothing);
      });

      testWidgets('Archived section lists archived conversations when expanded',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildSubject(
          conversations: [_conv('a', 'Recent chat')],
          archivedConversations: [_conv('b', 'Archived chat', archived: true)],
        ));
        expect(find.text('Archived'), findsOneWidget);
        // Collapsed by default: archived title not yet shown.
        expect(find.text('Archived chat'), findsNothing);

        await tester.tap(find.text('Archived'));
        await tester.pumpAndSettle();
        expect(find.text('Archived chat'), findsOneWidget);
      });

      testWidgets('tapping an archived conversation reports its id',
          (WidgetTester tester) async {
        String? selected;
        await tester.pumpWidget(buildSubject(
          archivedConversations: [_conv('b', 'Archived chat', archived: true)],
          onConversationSelected: (id) => selected = id,
        ));
        await tester.tap(find.text('Archived'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archived chat'));
        expect(selected, 'b');
      });
    });
  });
}
