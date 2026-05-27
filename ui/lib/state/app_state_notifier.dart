import 'package:flutter/foundation.dart';

import '../services/user_preferences_service.dart';

class AppStateNotifier extends ChangeNotifier {
  final UserPreferencesService? _prefsService;

  String? _selectedModel;
  double _temperature;

  AppStateNotifier({
    String? initialModel,
    double initialTemperature = 0.5,
    UserPreferencesService? prefsService,
  })  : _selectedModel = initialModel,
        _temperature = initialTemperature,
        _prefsService = prefsService;

  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;

  void setSelectedModel(String? model) {
    if (_selectedModel == model) return;
    _selectedModel = model;
    notifyListeners();
    _persist();
  }

  void setTemperature(double temperature) {
    if (_temperature == temperature) return;
    _temperature = temperature;
    notifyListeners();
    _persist();
  }

  void _persist() {
    // fire-and-forget; failures are non-fatal for UI state
    _prefsService?.save(
      UserPreferences(model: _selectedModel, temperature: _temperature),
    );
  }
}
