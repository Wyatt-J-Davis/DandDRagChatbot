import 'package:flutter/foundation.dart';

import '../services/user_preferences_service.dart';

class AppStateNotifier extends ChangeNotifier {
  final UserPreferencesService? _prefsService;

  String? _selectedModel;
  double _temperature;
  final List<String> _partyMembers = [];
  String? _noteTaker;

  AppStateNotifier({
    String? initialModel,
    double initialTemperature = 0.5,
    UserPreferencesService? prefsService,
  })  : _selectedModel = initialModel,
        _temperature = initialTemperature,
        _prefsService = prefsService;

  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;
  List<String> get partyMembers => List.unmodifiable(_partyMembers);
  String? get noteTaker => _noteTaker;

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

  void addPartyMember(String name) {
    if (name.trim().isEmpty) return;
    _partyMembers.add(name.trim());
    notifyListeners();
  }

  void removePartyMember(String name) {
    _partyMembers.remove(name);
    if (_noteTaker == name) _noteTaker = null;
    notifyListeners();
  }

  void setNoteTaker(String? name) {
    if (_noteTaker == name) return;
    _noteTaker = name;
    notifyListeners();
  }

  void _persist() {
    // fire-and-forget; failures are non-fatal for UI state
    _prefsService?.save(
      UserPreferences(model: _selectedModel, temperature: _temperature),
    );
  }
}
