import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../services/conversation_store.dart';
import '../services/party_service.dart';
import '../services/user_preferences_service.dart';

export '../models/conversation.dart' show Conversation;
export '../services/chat_service.dart' show ChatMessage, ChatSender, ChatSource;

class AppStateNotifier extends ChangeNotifier {
  final UserPreferencesService? _prefsService;
  final PartyService? _partyService;
  final ConversationStore? _conversationStore;

  String? _selectedModel;
  double _temperature;
  final List<String> _partyMembers = [];
  String? _noteTaker;
  String? _selectedNotesPath;
  bool _hasNotes = false;
  final List<Conversation> _conversations = [];
  String? _activeConversationId;

  AppStateNotifier({
    String? initialModel,
    double initialTemperature = 0.5,
    UserPreferencesService? prefsService,
    PartyService? partyService,
    ConversationStore? conversationStore,
    List<Conversation>? initialConversations,
  })  : _selectedModel = initialModel,
        _temperature = initialTemperature,
        _prefsService = prefsService,
        _partyService = partyService,
        _conversationStore = conversationStore {
    if (initialConversations != null) {
      _conversations.addAll(initialConversations);
    }
  }

  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;
  List<String> get partyMembers => List.unmodifiable(_partyMembers);
  String? get noteTaker => _noteTaker;
  String? get selectedNotesPath => _selectedNotesPath;
  bool get hasNotes => _hasNotes;

  List<Conversation> get conversations => List.unmodifiable(_conversations);

  String? get activeConversationId => _activeConversationId;

  // Non-archived conversations, newest-first by updatedAt, for the history list.
  List<Conversation> get recentConversations {
    final recent = _conversations.where((c) => !c.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(recent);
  }

  // Archived conversations, newest-first by updatedAt, for the Archived
  // section. Archived conversations are exempt from the 14-day prune.
  List<Conversation> get archivedConversations {
    final archived = _conversations.where((c) => c.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(archived);
  }

  Conversation? get activeConversation {
    if (_activeConversationId == null) return null;
    for (final conversation in _conversations) {
      if (conversation.id == _activeConversationId) return conversation;
    }
    return null;
  }

  // The active conversation's ordered messages, or an empty list when there is
  // no active conversation (welcome/empty state). Already unmodifiable.
  List<ChatMessage> get chatHistory => activeConversation?.messages ?? const [];

  void addChatMessage(ChatMessage message) {
    final now = DateTime.now();
    final active = activeConversation;
    if (active == null) {
      final conversation = Conversation(
        id: _generateConversationId(now),
        title: _deriveTitle(message.text),
        createdAt: now,
        updatedAt: now,
        messages: [message],
      );
      _conversations.insert(0, conversation);
      _activeConversationId = conversation.id;
    } else {
      // Appending bumps updatedAt and moves the conversation to the top of
      // the recent list (story 92).
      final updated = active.copyWith(
        messages: [...active.messages, message],
        updatedAt: now,
      );
      _conversations.removeWhere((c) => c.id == updated.id);
      _conversations.insert(0, updated);
    }
    notifyListeners();
    _persistConversations();
  }

  void setActiveConversation(String? id) {
    if (_activeConversationId == id) return;
    _activeConversationId = id;
    notifyListeners();
  }

  // Resets the Q&A view to the welcome/empty state without writing an entry;
  // a new conversation is only created when the next question is sent.
  void startNewChat() {
    if (_activeConversationId == null) return;
    _activeConversationId = null;
    notifyListeners();
  }

  // Overrides the auto-derived title with a custom name. Sets titleOverridden
  // so the first-question auto-title logic never overwrites it later.
  void renameConversation(String id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _conversations[index] = _conversations[index]
        .copyWith(title: trimmed, titleOverridden: true);
    notifyListeners();
    _persistConversations();
  }

  // Flips the archived flag. Archiving moves a conversation into the Archived
  // section (and exempts it from the prune); unarchiving returns it to the
  // recent, prunable list.
  void toggleArchiveConversation(String id) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final conversation = _conversations[index];
    _conversations[index] =
        conversation.copyWith(archived: !conversation.archived);
    notifyListeners();
    _persistConversations();
  }

  // Removes the conversation from the list (and from chat_history.json on the
  // next save). Works on archived conversations too.
  void deleteConversation(String id) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _conversations.removeAt(index);
    if (_activeConversationId == id) _activeConversationId = null;
    notifyListeners();
    _persistConversations();
  }

  static String _generateConversationId(DateTime now) =>
      now.microsecondsSinceEpoch.toString();

  static String _deriveTitle(String text) {
    final trimmed = text.trim();
    const maxLength = 40;
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength).trimRight()}…';
  }

  void _persistConversations() {
    // fire-and-forget; failures are non-fatal for UI state
    _conversationStore?.save(List.unmodifiable(_conversations));
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

