import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/widgets/app_shell.dart';

void main() {
  group('AppShell', () {
    testWidgets('shows spinner and status label while backend is initializing',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            ready: completer.future,
            child: const Text('Main Shell'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting backend…'), findsOneWidget);
      expect(find.text('Main Shell'), findsNothing);
    });

    testWidgets('replaces loading screen with child once ready resolves',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            ready: completer.future,
            child: const Text('Main Shell'),
          ),
        ),
      );

      expect(find.text('Main Shell'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Main Shell'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error message when ready future errors',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            ready: completer.future,
            child: const Text('Main Shell'),
          ),
        ),
      );

      completer.completeError(Exception('process crashed'));
      await tester.pumpAndSettle();

      expect(find.text('Main Shell'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Failed to start backend'), findsOneWidget);
    });

    testWidgets('shows timeout error when ready does not resolve within timeout',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            ready: completer.future,
            child: const Text('Main Shell'),
            timeout: const Duration(milliseconds: 100),
          ),
        ),
      );

      // Advance time past the timeout without completing the future.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Backend failed to start in time'),
          findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
