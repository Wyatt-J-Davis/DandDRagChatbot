import 'package:flutter/foundation.dart';

class AppStateNotifier extends ChangeNotifier {
  String? _selectedModel;
  double _temperature = 0.5;

  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;

  void setSelectedModel(String? model) {
    if (_selectedModel == model) return;
    _selectedModel = model;
    notifyListeners();
  }

  void setTemperature(double temperature) {
    if (_temperature == temperature) return;
    _temperature = temperature;
    notifyListeners();
  }
}
