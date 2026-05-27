import 'package:flutter/foundation.dart';

class AppStateNotifier extends ChangeNotifier {
  String? _selectedModel;

  String? get selectedModel => _selectedModel;

  void setSelectedModel(String? model) {
    if (_selectedModel == model) return;
    _selectedModel = model;
    notifyListeners();
  }
}
