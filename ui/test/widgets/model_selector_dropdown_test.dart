import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/model_selector_dropdown.dart';

Widget buildSubject({
  required Future<List<String>> modelsFuture,
  AppStateNotifier? notifier,
}) {
  final appState = notifier ?? AppStateNotifier();
  return MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ModelSelectorDropdown(
          modelsFuture: modelsFuture,
          appState: appState,
        ),
      ),
    ),
  );
}

void main() {
  group('ModelSelectorDropdown', () {
    testWidgets('shows loading indicator while future is pending',
        (WidgetTester tester) async {
      final completer = Completer<List<String>>();

      await tester.pumpWidget(buildSubject(modelsFuture: completer.future));
      // Do not settle — we want the pending state.

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);

      // Complete so no dangling async work remains after the test.
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows disabled dropdown with placeholder on empty list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(modelsFuture: Future.value([])),
      );
      await tester.pump(); // let the future resolve

      final dropdown =
          tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.onChanged, isNull);
      expect(find.text('No models available'), findsOneWidget);
    });

    testWidgets('shows disabled dropdown with placeholder on fetch error',
        (WidgetTester tester) async {
      // Attach an error handler immediately so the rejected future is never
      // "unhandled" from flutter_test's perspective.
      final errorFuture = Future<List<String>>.error(Exception('network error'))
          .catchError((_) => <String>[]);

      await tester.pumpWidget(buildSubject(modelsFuture: errorFuture));
      await tester.pump();

      final dropdown =
          tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.onChanged, isNull);
      expect(find.text('No models available'), findsOneWidget);
    });

    testWidgets('populates dropdown items from fetched model list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          modelsFuture: Future.value(['llama3', 'mistral']),
        ),
      );
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Open the dropdown to see the items.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('llama3'), findsWidgets);
      expect(find.text('mistral'), findsWidgets);
    });

    testWidgets('selecting a model updates AppStateNotifier',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(
          modelsFuture: Future.value(['llama3', 'mistral']),
          notifier: appState,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('mistral').last);
      await tester.pumpAndSettle();

      expect(appState.selectedModel, 'mistral');
    });

    testWidgets('first model is auto-selected after load',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(
          modelsFuture: Future.value(['llama3', 'mistral']),
          notifier: appState,
        ),
      );
      await tester.pump();

      expect(appState.selectedModel, 'llama3');
    });
  });
}
