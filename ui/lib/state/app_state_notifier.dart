import 'package:flutter/foundation.dart';

import '../services/chat_service.dart';
import '../services/party_service.dart';
import '../services/user_preferences_service.dart';

export '../services/chat_service.dart' show ChatMessage, ChatSender;

class AppStateNotifier extends ChangeNotifier {
  final UserPreferencesService? _prefsService;
  final PartyService? _partyService;

  String? _selectedModel;
  double _temperature;
  final List<String> _partyMembers = [];
  String? _noteTaker;
  String? _selectedNotesPath;
  bool _hasNotes = false;
  final List<ChatMessage> _chatHistory = [];

  AppStateNotifier({
    String? initialModel,
    double initialTemperature = 0.5,
    UserPreferencesService? prefsService,
    PartyService? partyService,
  })  : _selectedModel = initialModel,
        _temperature = initialTemperature,
        _prefsService = prefsService,
        _partyService = partyService;

  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;
  List<String> get partyMembers => List.unmodifiable(_partyMembers);
  String? get noteTaker => _noteTaker;
  String? get selectedNotesPath => _selectedNotesPath;
  bool get hasNotes => _hasNotes;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  void addChatMessage(ChatMessage message) {
    _chatHistory.add(message);
    notifyListeners();
  }

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
    _persistParty();
  }

  void removePartyMember(String name) {
    _partyMembers.remove(name);
    if (_noteTaker == name) _noteTaker = null;
    notifyListeners();
    _persistParty();
  }

  void setPartyMembers(List<String> members) {
    _partyMembers.clear();
    _partyMembers.addAll(
      members.map((n) => n.trim()).where((n) => n.isNotEmpty),
    );
    if (_noteTaker != null && !_partyMembers.contains(_noteTaker)) {
      _noteTaker = null;
    }
    notifyListeners();
  }

  void setSelectedNotesPath(String? path) {
    if (_selectedNotesPath == path) return;
    _selectedNotesPath = path;
    notifyListeners();
  }

  void setHasNotes(bool value) {
    if (_hasNotes == value) return;
    _hasNotes = value;
    notifyListeners();
  }

  void setNoteTaker(String? name) {
    if (_noteTaker == name) return;
    _noteTaker = name;
    notifyListeners();
    _persistParty();
  }

  void _persistParty() {
    _partyService?.savePartyMembers(List.unmodifiable(_partyMembers), _noteTaker);
  }

  void _persist() {
    // fire-and-forget; failures are non-fatal for UI state
    _prefsService?.save(
      UserPreferences(model: _selectedModel, temperature: _temperature),
    );
  }
}

