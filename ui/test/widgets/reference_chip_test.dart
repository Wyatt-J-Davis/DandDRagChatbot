import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/reference_chip.dart';

Widget buildSubject({required int index, VoidCallback? onTap}) {
  return MaterialApp(
    home: Scaffold(body: ReferenceChip(index: index, onTap: onTap)),
  );
}

void main() {
  group('ReferenceChip', () {
    testWidgets('displays "Source 1" for index 1', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(index: 1));
      expect(find.text('Source 1'), findsOneWidget);
    });

    testWidgets('displays "Source 2" for index 2', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(index: 2));
      expect(find.text('Source 2'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(index: 1, onTap: () => tapped = true));
      await tester.tap(find.byType(ActionChip));
      expect(tapped, isTrue);
    });

    testWidgets('renders without onTap', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(index: 1));
      expect(find.byType(ActionChip), findsOneWidget);
    });
  });
}
