import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/main_shell.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';

ModelService _stubModelService({List<String> models = const []}) {
  return ModelService(
    port: 9999,
    httpClient: MockClient(
      (_) async => http.Response(
        '[${models.map((m) => '"$m"').join(',')}]',
        200,
      ),
    ),
  );
}

/// Returns a ModelService whose first call returns an error and whose
/// subsequent calls return [models].
ModelService _stubRetryModelService({required List<String> models}) {
  var callCount = 0;
  return ModelService(
    port: 9999,
    httpClient: MockClient((_) async {
      callCount++;
      if (callCount == 1) {
        return http.Response('Internal Server Error', 500);
      }
      return http.Response(
        '[${models.map((m) => '"$m"').join(',')}]',
        200,
      );
    }),
  );
}

Widget buildSubject({
  AppStateNotifier? appState,
  ModelService? modelService,
}) {
  return MaterialApp(
    home: MainShell(
      appState: appState ?? AppStateNotifier(),
      modelService: modelService ?? _stubModelService(),
    ),
  );
}

void main() {
  group('MainShell', () {
    testWidgets(
        'renders a NavigationRail with Q&A, Summary, and Note Editor destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Q&A'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Note Editor'), findsOneWidget);
    });

    testWidgets('shows Q&A page stub by default', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(); // let model future resolve

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

      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

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
      await tester.pump();

      final navRailRect = tester.getRect(find.byType(NavigationRail));
      final sidebarRect = tester.getRect(find.byType(SidebarPanel));
      final contentRight = tester.getRect(find.text('Q&A Page')).right;

      expect(sidebarRect.left, greaterThanOrEqualTo(navRailRect.right));
      expect(contentRight, greaterThan(sidebarRect.right));
    });

    testWidgets(
        'ModelSelectorDropdown is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          modelService: _stubModelService(models: ['llama3']),
        ),
      );
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets(
        'ModelSelectorDropdown is not shown in SidebarPanel on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<String>), findsNothing);
    });

    testWidgets('shows error state then dropdown after tapping Retry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(
          modelService: _stubRetryModelService(models: ['llama3']),
        ),
      );
      await tester.pumpAndSettle();

      // First fetch fails — error message and retry button are shown.
      expect(find.text('No models found. Is Ollama running?'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);

      // Tap Retry — second fetch succeeds.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('No models found. Is Ollama running?'), findsNothing);
    });
  });
}
