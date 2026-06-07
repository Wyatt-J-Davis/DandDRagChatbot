import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/conversation_store.dart';
import 'package:ttrpg_chatbot/services/party_service.dart';
import 'package:ttrpg_chatbot/services/user_preferences_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';

class _FakePrefsService extends UserPreferencesService {
  final List<UserPreferences> saved = [];

  _FakePrefsService() : super(file: File(''));

  @override
  Future<UserPreferences> load() async => const UserPreferences();

  @override
  Future<void> save(UserPreferences prefs) async => saved.add(prefs);
}

class _FakePartyService extends PartyService {
  final List<({List<String> members, String? noteTaker})> saved = [];

  _FakePartyService() : super(port: 0);

  @override
  Future<({List<String> members, String? noteTaker})> fetchPartyMembers() async =>
      (members: <String>[], noteTaker: null);

  @override
  Future<void> savePartyMembers(List<String> members, String? noteTaker) async {
    saved.add((members: List.unmodifiable(members), noteTaker: noteTaker));
  }
}

class _FakeConversationStore extends ConversationStore {
  final List<List<Conversation>> saved = [];

  _FakeConversationStore() : super(file: File(''));

  @override
  Future<List<Conversation>> load() async => [];

  @override
  Future<void> save(List<Conversation> conversations) async {
    saved.add(List.unmodifiable(conversations));
  }
}

void main() {
  group('AppStateNotifier', () {
    test('selectedModel is null initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.selectedModel, isNull);
    });

    test('setSelectedModel updates selectedModel', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');
      expect(notifier.selectedModel, 'llama3');
    });

    test('setSelectedModel notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setSelectedModel('llama3');
      expect(callCount, 1);
    });

    test('setSelectedModel does not notify when value is unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');

      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setSelectedModel('llama3');
      expect(callCount, 0);
    });

    test('setSelectedModel accepts null to clear selection', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedModel('llama3');
      notifier.setSelectedModel(null);
      expect(notifier.selectedModel, isNull);
    });
  });

  group('temperature', () {
    test('temperature is 0.5 initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.temperature, 0.5);
    });

    test('setTemperature updates temperature', () {
      final notifier = AppStateNotifier();
      notifier.setTemperature(0.8);
      expect(notifier.temperature, 0.8);
    });

    test('setTemperature notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setTemperature(0.8);
      expect(callCount, 1);
    });

    test('setTemperature does not notify when value is unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setTemperature(0.8);

      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setTemperature(0.8);
      expect(callCount, 0);
    });
  });

  group('initialisation from stored preferences', () {
    test('uses provided initialModel', () {
      final notifier = AppStateNotifier(initialModel: 'mistral');
      expect(notifier.selectedModel, 'mistral');
    });

    test('uses provided initialTemperature', () {
      final notifier = AppStateNotifier(initialTemperature: 0.9);
      expect(notifier.temperature, 0.9);
    });

    test('defaults apply when no initial values given', () {
      final notifier = AppStateNotifier();
      expect(notifier.selectedModel, isNull);
      expect(notifier.temperature, 0.5);
    });
  });

  group('persistence', () {
    test('saves model when setSelectedModel is called', () async {
      final fake = _FakePrefsService();
      final notifier = AppStateNotifier(prefsService: fake);

      notifier.setSelectedModel('llama3');
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved, isNotEmpty);
      expect(fake.saved.last.model, 'llama3');
    });

    test('saves temperature when setTemperature is called', () async {
      final fake = _FakePrefsService();
      final notifier = AppStateNotifier(prefsService: fake);

      notifier.setTemperature(0.7);
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved, isNotEmpty);
      expect(fake.saved.last.temperature, 0.7);
    });

    test('does not save when model is unchanged', () async {
      final fake = _FakePrefsService();
      final notifier = AppStateNotifier(prefsService: fake);

      notifier.setSelectedModel('llama3');
      await Future<void>.delayed(Duration.zero);
      final savedBefore = fake.saved.length;

      notifier.setSelectedModel('llama3');
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved.length, savedBefore);
    });

    test('does not save when temperature is unchanged', () async {
      final fake = _FakePrefsService();
      final notifier = AppStateNotifier(initialTemperature: 0.5, prefsService: fake);

      notifier.setTemperature(0.5);
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved, isEmpty);
    });

    test('saved preferences include current model and temperature together', () async {
      final fake = _FakePrefsService();
      final notifier = AppStateNotifier(
        initialModel: 'mistral',
        initialTemperature: 0.6,
        prefsService: fake,
      );

      notifier.setTemperature(0.9);
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved.last.model, 'mistral');
      expect(fake.saved.last.temperature, 0.9);
    });
  });

  group('partyMembers', () {
    test('partyMembers is empty initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.partyMembers, isEmpty);
    });

    test('addPartyMember appends name to partyMembers', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      expect(notifier.partyMembers, ['Aria']);
    });

    test('addPartyMember notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.addPartyMember('Aria');
      expect(callCount, 1);
    });

    test('addPartyMember ignores empty name', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.addPartyMember('');
      expect(notifier.partyMembers, isEmpty);
      expect(callCount, 0);
    });

    test('addPartyMember ignores whitespace-only name', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('   ');
      expect(notifier.partyMembers, isEmpty);
    });

    test('addPartyMember trims surrounding whitespace', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('  Aria  ');
      expect(notifier.partyMembers, ['Aria']);
    });

    test('addPartyMember supports multiple members', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.addPartyMember('Borin');
      expect(notifier.partyMembers, ['Aria', 'Borin']);
    });
  });

  group('removePartyMember', () {
    test('removePartyMember removes the member from the list', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.removePartyMember('Aria');
      expect(notifier.partyMembers, isEmpty);
    });

    test('removePartyMember notifies listeners', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.removePartyMember('Aria');
      expect(callCount, 1);
    });

    test('removePartyMember clears noteTaker when that member is removed', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      notifier.removePartyMember('Aria');
      expect(notifier.noteTaker, isNull);
    });

    test('removePartyMember does not clear noteTaker when a different member is removed', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.addPartyMember('Borin');
      notifier.setNoteTaker('Aria');
      notifier.removePartyMember('Borin');
      expect(notifier.noteTaker, 'Aria');
    });
  });

  group('noteTaker', () {
    test('noteTaker is null initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.noteTaker, isNull);
    });

    test('setNoteTaker sets the note-taker', () {
      final notifier = AppStateNotifier();
      notifier.setNoteTaker('Aria');
      expect(notifier.noteTaker, 'Aria');
    });

    test('setNoteTaker notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setNoteTaker('Aria');
      expect(callCount, 1);
    });

    test('setNoteTaker does not notify when value unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setNoteTaker('Aria');
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setNoteTaker('Aria');
      expect(callCount, 0);
    });

    test('setNoteTaker can clear note-taker with null', () {
      final notifier = AppStateNotifier();
      notifier.setNoteTaker('Aria');
      notifier.setNoteTaker(null);
      expect(notifier.noteTaker, isNull);
    });

    test('setNoteTaker replaces previous note-taker', () {
      final notifier = AppStateNotifier();
      notifier.setNoteTaker('Aria');
      notifier.setNoteTaker('Borin');
      expect(notifier.noteTaker, 'Borin');
    });
  });

  group('hasNotes', () {
    test('hasNotes is false initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.hasNotes, isFalse);
    });

    test('setHasNotes updates hasNotes', () {
      final notifier = AppStateNotifier();
      notifier.setHasNotes(true);
      expect(notifier.hasNotes, isTrue);
    });

    test('setHasNotes notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setHasNotes(true);
      expect(callCount, 1);
    });

    test('setHasNotes does not notify when value unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setHasNotes(true);
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setHasNotes(true);
      expect(callCount, 0);
    });
  });

  group('party persistence', () {
    test('addPartyMember saves members to party service', () async {
      final fake = _FakePartyService();
      final notifier = AppStateNotifier(partyService: fake);
      notifier.addPartyMember('Aria');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved, isNotEmpty);
      expect(fake.saved.last.members, ['Aria']);
      expect(fake.saved.last.noteTaker, isNull);
    });

    test('removePartyMember saves updated members to party service', () async {
      final fake = _FakePartyService();
      final notifier = AppStateNotifier(partyService: fake);
      notifier.addPartyMember('Aria');
      notifier.addPartyMember('Borin');
      notifier.removePartyMember('Aria');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.members, ['Borin']);
    });

    test('setNoteTaker saves noteTaker to party service', () async {
      final fake = _FakePartyService();
      final notifier = AppStateNotifier(partyService: fake);
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.noteTaker, 'Aria');
      expect(fake.saved.last.members, ['Aria']);
    });

    test('setNoteTaker with null saves null noteTaker', () async {
      final fake = _FakePartyService();
      final notifier = AppStateNotifier(partyService: fake);
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      notifier.setNoteTaker(null);
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.noteTaker, isNull);
    });

    test('removePartyMember that is noteTaker saves null noteTaker', () async {
      final fake = _FakePartyService();
      final notifier = AppStateNotifier(partyService: fake);
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      notifier.removePartyMember('Aria');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.noteTaker, isNull);
      expect(fake.saved.last.members, isEmpty);
    });
  });

  group('setPartyMembers', () {
    test('replaces all party members', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('OldMember');
      notifier.setPartyMembers(['Aria', 'Borin']);
      expect(notifier.partyMembers, ['Aria', 'Borin']);
    });

    test('notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setPartyMembers(['Aria']);
      expect(callCount, 1);
    });

    test('trims whitespace and ignores empty names', () {
      final notifier = AppStateNotifier();
      notifier.setPartyMembers(['  Aria  ', '', '  ', 'Borin']);
      expect(notifier.partyMembers, ['Aria', 'Borin']);
    });

    test('clears noteTaker when that member is no longer in the list', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      notifier.setPartyMembers(['Borin']);
      expect(notifier.noteTaker, isNull);
    });

    test('keeps noteTaker when that member is still in the list', () {
      final notifier = AppStateNotifier();
      notifier.addPartyMember('Aria');
      notifier.setNoteTaker('Aria');
      notifier.setPartyMembers(['Aria', 'Borin']);
      expect(notifier.noteTaker, 'Aria');
    });
  });

  group('chatHistory', () {
    test('chatHistory is empty initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.chatHistory, isEmpty);
    });

    test('addChatMessage appends to chatHistory', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'Hello'));
      expect(notifier.chatHistory.length, 1);
      expect(notifier.chatHistory.first.text, 'Hello');
    });

    test('addChatMessage notifies listeners', () {
      final notifier = AppStateNotifier();
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'Hello'));
      expect(calls, 1);
    });

    test('chatHistory is unmodifiable', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'Hello'));
      final history = notifier.chatHistory;
      expect(
        () => history.add(
            const ChatMessage(sender: ChatSender.assistant, text: 'x')),
        throwsUnsupportedError,
      );
    });

    test('multiple messages accumulate in order', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.assistant, text: 'a1'));
      expect(notifier.chatHistory[0].text, 'q1');
      expect(notifier.chatHistory[1].text, 'a1');
    });

    test('chatHistory persists across multiple listener rebuilds', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'first'));
      notifier.setSelectedModel('llama3'); // unrelated state change
      expect(notifier.chatHistory.length, 1);
    });
  });

  group('selectedNotesPath', () {
    test('selectedNotesPath is null initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.selectedNotesPath, isNull);
    });

    test('setSelectedNotesPath updates selectedNotesPath', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedNotesPath(r'C:\Users\user\notes.txt');
      expect(notifier.selectedNotesPath, r'C:\Users\user\notes.txt');
    });

    test('setSelectedNotesPath notifies listeners', () {
      final notifier = AppStateNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setSelectedNotesPath(r'C:\notes.txt');
      expect(callCount, 1);
    });

    test('setSelectedNotesPath does not notify when value unchanged', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedNotesPath(r'C:\notes.txt');
      int callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.setSelectedNotesPath(r'C:\notes.txt');
      expect(callCount, 0);
    });

    test('setSelectedNotesPath can clear path with null', () {
      final notifier = AppStateNotifier();
      notifier.setSelectedNotesPath(r'C:\notes.txt');
      notifier.setSelectedNotesPath(null);
      expect(notifier.selectedNotesPath, isNull);
    });
  });

  group('active conversation', () {
    test('no active conversation on startup yields empty chatHistory', () {
      final notifier = AppStateNotifier();
      expect(notifier.activeConversation, isNull);
      expect(notifier.chatHistory, isEmpty);
    });

    test('startup does not auto-activate a loaded conversation', () {
      final loaded = Conversation(
        id: 'old',
        title: 'Old chat',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        messages: const [ChatMessage(sender: ChatSender.user, text: 'hi')],
      );
      final notifier =
          AppStateNotifier(initialConversations: [loaded]);
      expect(notifier.conversations, hasLength(1));
      expect(notifier.activeConversation, isNull);
      expect(notifier.chatHistory, isEmpty);
    });

    test('first message creates a conversation titled from the question', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(const ChatMessage(
          sender: ChatSender.user, text: 'Who is the villain?'));

      expect(notifier.conversations, hasLength(1));
      final active = notifier.activeConversation;
      expect(active, isNotNull);
      expect(active!.title, 'Who is the villain?');
      expect(notifier.chatHistory, hasLength(1));
      expect(notifier.chatHistory.first.text, 'Who is the villain?');
    });

    test('long first question is truncated for the title', () {
      final notifier = AppStateNotifier();
      final longQuestion =
          'Tell me absolutely everything that has ever happened in this campaign';
      notifier.addChatMessage(
          ChatMessage(sender: ChatSender.user, text: longQuestion));
      final title = notifier.activeConversation!.title;
      expect(title.length, lessThan(longQuestion.length));
      expect(title, endsWith('…'));
    });

    test('subsequent messages append to the active conversation', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.assistant, text: 'a1'));

      expect(notifier.conversations, hasLength(1));
      expect(notifier.chatHistory.map((m) => m.text), ['q1', 'a1']);
    });

    test('appending a message bumps updatedAt', () async {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      final firstUpdatedAt = notifier.activeConversation!.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 2));
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.assistant, text: 'a1'));
      final secondUpdatedAt = notifier.activeConversation!.updatedAt;

      expect(secondUpdatedAt.isAfter(firstUpdatedAt), isTrue);
    });

    test('chatHistory remains unmodifiable', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      expect(
        () => notifier.chatHistory.add(
            const ChatMessage(sender: ChatSender.assistant, text: 'x')),
        throwsUnsupportedError,
      );
    });

    test('persists conversation list on first message', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(conversationStore: fake);
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved, isNotEmpty);
      expect(fake.saved.last, hasLength(1));
      expect(fake.saved.last.first.messages.first.text, 'q1');
    });

    test('persists again when a message is appended', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(conversationStore: fake);
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.assistant, text: 'a1'));
      await Future<void>.delayed(Duration.zero);

      expect(fake.saved.length, 2);
      expect(fake.saved.last.first.messages, hasLength(2));
    });

    test('persisted conversation preserves message sources', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(conversationStore: fake);
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      notifier.addChatMessage(const ChatMessage(
        sender: ChatSender.assistant,
        text: 'a1',
        sources: [ChatSource(content: 'Session 1', date: '2026-05-01')],
      ));
      await Future<void>.delayed(Duration.zero);

      final saved = fake.saved.last.first;
      expect(saved.messages.last.sources.first.content, 'Session 1');
      expect(saved.messages.last.sources.first.date, '2026-05-01');
    });
  });

  group('recentConversations', () {
    Conversation conv(String id, DateTime updatedAt, {bool archived = false}) =>
        Conversation(
          id: id,
          title: 'conv $id',
          createdAt: updatedAt,
          updatedAt: updatedAt,
          archived: archived,
        );

    test('is empty initially', () {
      final notifier = AppStateNotifier();
      expect(notifier.recentConversations, isEmpty);
    });

    test('returns non-archived conversations sorted newest-first by updatedAt', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
        conv('b', DateTime(2026, 5, 3)),
        conv('c', DateTime(2026, 5, 2)),
      ]);
      expect(
        notifier.recentConversations.map((c) => c.id),
        ['b', 'c', 'a'],
      );
    });

    test('excludes archived conversations', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
        conv('b', DateTime(2026, 5, 2), archived: true),
      ]);
      expect(notifier.recentConversations.map((c) => c.id), ['a']);
    });

    test('is unmodifiable', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
      ]);
      expect(
        () => notifier.recentConversations.add(conv('z', DateTime(2026, 5, 9))),
        throwsUnsupportedError,
      );
    });
  });

  group('setActiveConversation', () {
    Conversation conv(String id) => Conversation(
          id: id,
          title: 'conv $id',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          messages: [ChatMessage(sender: ChatSender.user, text: 'in $id')],
        );

    test('sets the active conversation and exposes its messages', () {
      final notifier = AppStateNotifier(
          initialConversations: [conv('a'), conv('b')]);
      notifier.setActiveConversation('b');
      expect(notifier.activeConversationId, 'b');
      expect(notifier.activeConversation!.id, 'b');
      expect(notifier.chatHistory.first.text, 'in b');
    });

    test('notifies listeners', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.setActiveConversation('a');
      expect(calls, 1);
    });

    test('does not notify when already active', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      notifier.setActiveConversation('a');
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.setActiveConversation('a');
      expect(calls, 0);
    });
  });

  group('startNewChat', () {
    test('clears the active conversation to the welcome/empty state', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      expect(notifier.activeConversation, isNotNull);

      notifier.startNewChat();
      expect(notifier.activeConversationId, isNull);
      expect(notifier.chatHistory, isEmpty);
    });

    test('writes no new conversation entry', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      notifier.startNewChat();
      expect(notifier.conversations, hasLength(1));
    });

    test('notifies listeners when there was an active conversation', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'q1'));
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.startNewChat();
      expect(calls, 1);
    });

    test('does not notify when already at the welcome state', () {
      final notifier = AppStateNotifier();
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.startNewChat();
      expect(calls, 0);
    });

    test('next message after startNewChat begins a fresh conversation', () {
      final notifier = AppStateNotifier();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'first chat'));
      notifier.startNewChat();
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'second chat'));

      expect(notifier.conversations, hasLength(2));
      expect(notifier.activeConversation!.title, 'second chat');
    });
  });

  group('renameConversation', () {
    Conversation conv(String id) => Conversation(
          id: id,
          title: 'conv $id',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          messages: const [ChatMessage(sender: ChatSender.user, text: 'q')],
        );

    test('updates the title and sets titleOverridden', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      notifier.renameConversation('a', 'My custom title');
      final renamed = notifier.conversations.first;
      expect(renamed.title, 'My custom title');
      expect(renamed.titleOverridden, isTrue);
    });

    test('trims the new title', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      notifier.renameConversation('a', '  Trimmed  ');
      expect(notifier.conversations.first.title, 'Trimmed');
    });

    test('ignores an empty or whitespace-only title', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      notifier.renameConversation('a', '   ');
      expect(notifier.conversations.first.title, 'conv a');
      expect(notifier.conversations.first.titleOverridden, isFalse);
    });

    test('notifies listeners', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.renameConversation('a', 'New');
      expect(calls, 1);
    });

    test('does nothing for an unknown id', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.renameConversation('missing', 'New');
      expect(calls, 0);
      expect(notifier.conversations.first.title, 'conv a');
    });

    test('persists the rename', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(
        initialConversations: [conv('a')],
        conversationStore: fake,
      );
      notifier.renameConversation('a', 'Saved title');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.first.title, 'Saved title');
    });

    test('sending further messages does not revert a renamed title', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      notifier.setActiveConversation('a');
      notifier.renameConversation('a', 'Locked title');
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.assistant, text: 'reply'));
      expect(notifier.activeConversation!.title, 'Locked title');
      expect(notifier.activeConversation!.titleOverridden, isTrue);
    });
  });

  group('archiving', () {
    Conversation conv(String id, DateTime updatedAt, {bool archived = false}) =>
        Conversation(
          id: id,
          title: 'conv $id',
          createdAt: updatedAt,
          updatedAt: updatedAt,
          archived: archived,
        );

    test('toggleArchiveConversation archives a recent conversation', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
      ]);
      notifier.toggleArchiveConversation('a');
      expect(notifier.recentConversations, isEmpty);
      expect(notifier.archivedConversations.map((c) => c.id), ['a']);
    });

    test('toggleArchiveConversation unarchives an archived conversation', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1), archived: true),
      ]);
      notifier.toggleArchiveConversation('a');
      expect(notifier.archivedConversations, isEmpty);
      expect(notifier.recentConversations.map((c) => c.id), ['a']);
    });

    test('notifies listeners', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
      ]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.toggleArchiveConversation('a');
      expect(calls, 1);
    });

    test('does nothing for an unknown id', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1)),
      ]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.toggleArchiveConversation('missing');
      expect(calls, 0);
    });

    test('persists the archive toggle', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(
        initialConversations: [conv('a', DateTime(2026, 5, 1))],
        conversationStore: fake,
      );
      notifier.toggleArchiveConversation('a');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.first.archived, isTrue);
    });

    test('archivedConversations is newest-first by updatedAt', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1), archived: true),
        conv('b', DateTime(2026, 5, 3), archived: true),
        conv('c', DateTime(2026, 5, 2), archived: true),
      ]);
      expect(notifier.archivedConversations.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('archivedConversations is unmodifiable', () {
      final notifier = AppStateNotifier(initialConversations: [
        conv('a', DateTime(2026, 5, 1), archived: true),
      ]);
      expect(
        () => notifier.archivedConversations
            .add(conv('z', DateTime(2026, 5, 9))),
        throwsUnsupportedError,
      );
    });
  });

  group('deleteConversation', () {
    Conversation conv(String id, {bool archived = false}) => Conversation(
          id: id,
          title: 'conv $id',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          archived: archived,
          messages: const [ChatMessage(sender: ChatSender.user, text: 'q')],
        );

    test('removes the conversation from the list', () {
      final notifier =
          AppStateNotifier(initialConversations: [conv('a'), conv('b')]);
      notifier.deleteConversation('a');
      expect(notifier.conversations.map((c) => c.id), ['b']);
    });

    test('clears the active conversation when the active one is deleted', () {
      final notifier =
          AppStateNotifier(initialConversations: [conv('a'), conv('b')]);
      notifier.setActiveConversation('a');
      notifier.deleteConversation('a');
      expect(notifier.activeConversationId, isNull);
      expect(notifier.chatHistory, isEmpty);
    });

    test('keeps the active conversation when a different one is deleted', () {
      final notifier =
          AppStateNotifier(initialConversations: [conv('a'), conv('b')]);
      notifier.setActiveConversation('a');
      notifier.deleteConversation('b');
      expect(notifier.activeConversationId, 'a');
    });

    test('deletes an archived conversation', () {
      final notifier = AppStateNotifier(
          initialConversations: [conv('a', archived: true), conv('b')]);
      notifier.deleteConversation('a');
      expect(notifier.conversations.map((c) => c.id), ['b']);
      expect(notifier.archivedConversations, isEmpty);
    });

    test('notifies listeners', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.deleteConversation('a');
      expect(calls, 1);
    });

    test('does nothing for an unknown id', () {
      final notifier = AppStateNotifier(initialConversations: [conv('a')]);
      int calls = 0;
      notifier.addListener(() => calls++);
      notifier.deleteConversation('missing');
      expect(calls, 0);
      expect(notifier.conversations, hasLength(1));
    });

    test('persists the deletion', () async {
      final fake = _FakeConversationStore();
      final notifier = AppStateNotifier(
        initialConversations: [conv('a'), conv('b')],
        conversationStore: fake,
      );
      notifier.deleteConversation('a');
      await Future<void>.delayed(Duration.zero);
      expect(fake.saved.last.map((c) => c.id), ['b']);
    });
  });

  group('append moves a reopened conversation to the top', () {
    test('asking in a reopened conversation moves it newest-first', () async {
      final older = Conversation(
        id: 'older',
        title: 'older',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        messages: const [ChatMessage(sender: ChatSender.user, text: 'old q')],
      );
      final newer = Conversation(
        id: 'newer',
        title: 'newer',
        createdAt: DateTime(2026, 5, 2),
        updatedAt: DateTime(2026, 5, 2),
        messages: const [ChatMessage(sender: ChatSender.user, text: 'new q')],
      );
      final notifier =
          AppStateNotifier(initialConversations: [newer, older]);

      notifier.setActiveConversation('older');
      notifier.addChatMessage(
          const ChatMessage(sender: ChatSender.user, text: 'follow up'));

      expect(notifier.recentConversations.first.id, 'older');
      expect(notifier.activeConversation!.messages.map((m) => m.text),
          ['old q', 'follow up']);
    });
  });
}
