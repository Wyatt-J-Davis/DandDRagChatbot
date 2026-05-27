import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
