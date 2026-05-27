import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttrpg_chatbot/services/model_service.dart';
import 'package:ttrpg_chatbot/services/user_preferences_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/main_shell.dart';
import 'package:ttrpg_chatbot/widgets/sidebar_panel.dart';
import 'package:ttrpg_chatbot/widgets/party_member_input.dart';
import 'package:ttrpg_chatbot/widgets/temperature_slider.dart';

class _FakePrefsService extends UserPreferencesService {
  UserPreferences _stored;
  final List<UserPreferences> saved = [];

  _FakePrefsService(UserPreferences initial)
      : _stored = initial,
        super(file: File(''));

  @override
  Future<UserPreferences> load() async => _stored;

  @override
  Future<void> save(UserPreferences prefs) async {
    _stored = prefs;
    saved.add(prefs);
  }
}

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
  UserPreferencesService? prefsService,
}) {
  return MaterialApp(
    home: MainShell(
      appState: appState ?? AppStateNotifier(),
      modelService: modelService ?? _stubModelService(),
      prefsService: prefsService,
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

    testWidgets('TemperatureSlider is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(TemperatureSlider), findsOneWidget);
    });

    testWidgets('TemperatureSlider is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperatureSlider), findsNothing);
    });

    testWidgets('TemperatureSlider is not shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperatureSlider), findsNothing);
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

    testWidgets('loads saved temperature from UserPreferencesService on startup',
        (WidgetTester tester) async {
      final fakePrefs = _FakePrefsService(
        const UserPreferences(model: null, temperature: 0.8),
      );
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(appState: appState, prefsService: fakePrefs),
      );
      await tester.pump();

      expect(appState.temperature, closeTo(0.8, 0.001));
    });

    testWidgets('saves preferences when AppStateNotifier changes',
        (WidgetTester tester) async {
      final fakePrefs = _FakePrefsService(const UserPreferences());
      final appState = AppStateNotifier();

      await tester.pumpWidget(
        buildSubject(appState: appState, prefsService: fakePrefs),
      );
      await tester.pump();

      appState.setTemperature(0.9);

      expect(fakePrefs.saved, isNotEmpty);
      expect(fakePrefs.saved.last.temperature, closeTo(0.9, 0.001));
    });

    testWidgets('PartyMemberInput is shown in SidebarPanel on Q&A page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(PartyMemberInput), findsOneWidget);
    });

    testWidgets('PartyMemberInput is not shown on Summary page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyMemberInput), findsNothing);
    });

    testWidgets('PartyMemberInput is not shown on Note Editor page',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Note Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyMemberInput), findsNothing);
    });
  });
}
