import 'package:flutter/material.dart';

import '../state/app_state_notifier.dart';

class TemperatureSlider extends StatelessWidget {
  final AppStateNotifier appState;

  const TemperatureSlider({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appState.temperature.toStringAsFixed(1)),
            Slider(
              min: 0.0,
              max: 1.0,
              value: appState.temperature,
              onChanged: appState.setTemperature,
            ),
          ],
        );
      },
    );
  }
}
