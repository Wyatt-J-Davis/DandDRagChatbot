import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/widgets/temperature_slider.dart';

Widget buildSubject({AppStateNotifier? appState}) {
  return MaterialApp(
    home: Scaffold(
      body: TemperatureSlider(appState: appState ?? AppStateNotifier()),
    ),
  );
}

void main() {
  group('TemperatureSlider', () {
    testWidgets('renders a Slider widget', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows numeric readout of current value',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('slider has min 0.0 and max 1.0', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0.0);
      expect(slider.max, 1.0);
    });

    testWidgets('initial value comes from AppStateNotifier',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();
      appState.setTemperature(0.3);

      await tester.pumpWidget(buildSubject(appState: appState));
      expect(find.text('0.3'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.3);
    });

    testWidgets('moving slider updates AppStateNotifier temperature',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();

      await tester.pumpWidget(buildSubject(appState: appState));

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      expect(appState.temperature, isNot(0.5));
    });

    testWidgets('moving slider updates the readout text',
        (WidgetTester tester) async {
      final appState = AppStateNotifier();

      await tester.pumpWidget(buildSubject(appState: appState));

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      // The readout should no longer show the initial value.
      expect(find.text('0.5'), findsNothing);
    });
  });
}
