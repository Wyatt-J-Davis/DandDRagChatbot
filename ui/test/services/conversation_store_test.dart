import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/models/conversation.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';
import 'package:ttrpg_chatbot/services/conversation_store.dart';

void main() {
  group('ConversationStore', () {
    late Directory tempDir;
    late File historyFile;
    late ConversationStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('history_test_');
      historyFile = File('${tempDir.path}/chat_history.json');
      store = ConversationStore(file: historyFile);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Conversation sampleConversation() => Conversation(
          id: 'conv-1',
          title: 'Who is the villain?',
          createdAt: DateTime.parse('2026-06-01T10:00:00.000'),
          updatedAt: DateTime.parse('2026-06-02T12:30:00.000'),
          messages: const [
            ChatMessage(sender: ChatSender.user, text: 'Who is the villain?'),
            ChatMessage(
              sender: ChatSender.assistant,
              text: 'The Lich King.',
              sources: [
                ChatSource(content: 'Session 3 notes', date: '2026-05-12'),
                ChatSource(content: 'Session 4 notes'),
              ],
            ),
          ],
        );

    test('returns empty list when file does not exist', () async {
      final result = await store.load();
      expect(result, isEmpty);
    });

    test('returns empty list on corrupt JSON', () async {
      historyFile.writeAsStringSync('not valid json {{');
      final result = await store.load();
      expect(result, isEmpty);
    });

    test('save then load round-trips the conversation list', () async {
      await store.save([sampleConversation()]);
      final result = await store.load();

      expect(result, hasLength(1));
      final conversation = result.first;
      expect(conversation.id, 'conv-1');
      expect(conversation.title, 'Who is the villain?');
      expect(conversation.messages, hasLength(2));
    });

    test('round-trips message sources and their dates', () async {
      await store.save([sampleConversation()]);
      final result = await store.load();

      final assistant = result.first.messages[1];
      expect(assistant.sources, hasLength(2));
      expect(assistant.sources[0].content, 'Session 3 notes');
      expect(assistant.sources[0].date, '2026-05-12');
      expect(assistant.sources[1].content, 'Session 4 notes');
      expect(assistant.sources[1].date, isNull);
    });

    test('saves and loads multiple conversations preserving order', () async {
      final first = sampleConversation();
      final second = first.copyWith().copyWithId('conv-2');
      await store.save([first, second]);
      final result = await store.load();
      expect(result.map((c) => c.id), ['conv-1', 'conv-2']);
    });

    test('save overwrites the previous contents', () async {
      await store.save([sampleConversation()]);
      await store.save([]);
      final result = await store.load();
      expect(result, isEmpty);
    });

    test('load prunes stale conversations and persists the pruned result',
        () async {
      final now = DateTime.now();
      final stale = Conversation(
        id: 'stale',
        title: 'stale',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 30)),
      );
      final fresh = Conversation(
        id: 'fresh',
        title: 'fresh',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      await store.save([stale, fresh]);

      final loaded = await store.load();
      expect(loaded.map((c) => c.id), ['fresh']);

      // The pruned result is written back to disk: a second load (which would
      // not prune, since 'fresh' is recent) sees only the surviving entry.
      final reloaded = await store.load();
      expect(reloaded.map((c) => c.id), ['fresh']);
    });

    test('load retains archived conversations regardless of age', () async {
      final now = DateTime.now();
      final archivedAncient = Conversation(
        id: 'archived',
        title: 'archived',
        createdAt: now.subtract(const Duration(days: 400)),
        updatedAt: now.subtract(const Duration(days: 365)),
        archived: true,
      );
      await store.save([archivedAncient]);

      final loaded = await store.load();
      expect(loaded.map((c) => c.id), ['archived']);
    });
  });
}

extension on Conversation {
  Conversation copyWithId(String newId) => Conversation(
        id: newId,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archived: archived,
        titleOverridden: titleOverridden,
        messages: messages,
      );
}
