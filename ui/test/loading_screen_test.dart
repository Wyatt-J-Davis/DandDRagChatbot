import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ttrpg_chatbot/loading_screen.dart';

void main() {
  group('LoadingScreen', () {
    testWidgets('shows spinner and default status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadingScreen()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting backend…'), findsOneWidget);
    });

    testWidgets('accepts a custom status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(statusLabel: 'Connecting…'),
        ),
      );

      expect(find.text('Connecting…'), findsOneWidget);
    });
  });
}
