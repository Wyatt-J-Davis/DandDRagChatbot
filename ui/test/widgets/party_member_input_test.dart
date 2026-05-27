import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/party_member_input.dart';

Widget buildSubject({AppStateNotifier? appState}) {
  return MaterialApp(
    home: Scaffold(
      body: PartyMemberInput(appState: appState ?? AppStateNotifier()),
    ),
  );
}

void main() {
  group('PartyMemberInput', () {
    testWidgets('renders a TextField', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders an Add button', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('tapping Add with a name adds it to AppStateNotifier',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      await tester.pumpWidget(buildSubject(appState: appState));

      await tester.enterText(find.byType(TextField), 'Aria');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(appState.partyMembers, ['Aria']);
    });

    testWidgets('tapping Add clears the text field', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'Aria');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Aria'), findsNothing);
    });

    testWidgets('added name is displayed in the list', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'Aria');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(find.text('Aria'), findsOneWidget);
    });

    testWidgets('tapping Add with empty field does nothing',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      await tester.pumpWidget(buildSubject(appState: appState));

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(appState.partyMembers, isEmpty);
    });

    testWidgets('tapping Add with whitespace-only does nothing',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      await tester.pumpWidget(buildSubject(appState: appState));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(appState.partyMembers, isEmpty);
    });

    testWidgets('pre-existing party members are shown on build',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.addPartyMember('Borin');
      appState.addPartyMember('Cass');

      await tester.pumpWidget(buildSubject(appState: appState));

      expect(find.text('Borin'), findsOneWidget);
      expect(find.text('Cass'), findsOneWidget);
    });

    testWidgets('list updates when AppStateNotifier notifies',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      await tester.pumpWidget(buildSubject(appState: appState));

      appState.addPartyMember('Dex');
      await tester.pump();

      expect(find.text('Dex'), findsOneWidget);
    });
  });
}
