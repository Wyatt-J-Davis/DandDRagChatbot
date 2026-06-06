import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/models/conversation.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';

void main() {
  group('Conversation', () {
    final createdAt = DateTime.parse('2026-06-01T10:00:00.000');
    final updatedAt = DateTime.parse('2026-06-02T12:30:00.000');

    Conversation buildConversation() => Conversation(
          id: 'conv-1',
          title: 'Who is the villain?',
          createdAt: createdAt,
          updatedAt: updatedAt,
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

    test('defaults archived and titleOverridden to false', () {
      final conversation = Conversation(
        id: 'x',
        title: 't',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(conversation.archived, isFalse);
      expect(conversation.titleOverridden, isFalse);
      expect(conversation.messages, isEmpty);
    });

    test('messages list is unmodifiable', () {
      final conversation = buildConversation();
      expect(
        () => conversation.messages.add(
            const ChatMessage(sender: ChatSender.user, text: 'x')),
        throwsUnsupportedError,
      );
    });

    test('toJson includes all scalar fields', () {
      final json = buildConversation().toJson();
      expect(json['id'], 'conv-1');
      expect(json['title'], 'Who is the villain?');
      expect(json['createdAt'], createdAt.toIso8601String());
      expect(json['updatedAt'], updatedAt.toIso8601String());
      expect(json['archived'], false);
      expect(json['titleOverridden'], false);
      expect((json['messages'] as List), hasLength(2));
    });

    test('round-trips through JSON preserving messages, sources and dates', () {
      final original = buildConversation();
      final restored = Conversation.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.archived, original.archived);
      expect(restored.titleOverridden, original.titleOverridden);

      expect(restored.messages, hasLength(2));
      expect(restored.messages[0].sender, ChatSender.user);
      expect(restored.messages[0].text, 'Who is the villain?');

      final assistant = restored.messages[1];
      expect(assistant.sender, ChatSender.assistant);
      expect(assistant.text, 'The Lich King.');
      expect(assistant.sources, hasLength(2));
      expect(assistant.sources[0].content, 'Session 3 notes');
      expect(assistant.sources[0].date, '2026-05-12');
      expect(assistant.sources[1].content, 'Session 4 notes');
      expect(assistant.sources[1].date, isNull);
    });

    test('round-trips archived and titleOverridden true', () {
      final conversation = Conversation(
        id: 'c',
        title: 'Renamed',
        createdAt: createdAt,
        updatedAt: updatedAt,
        archived: true,
        titleOverridden: true,
      );
      final restored = Conversation.fromJson(conversation.toJson());
      expect(restored.archived, isTrue);
      expect(restored.titleOverridden, isTrue);
    });

    test('copyWith overrides only the given fields', () {
      final conversation = buildConversation();
      final later = DateTime.parse('2026-06-03T09:00:00.000');
      final updated = conversation.copyWith(
        updatedAt: later,
        archived: true,
      );
      expect(updated.id, conversation.id);
      expect(updated.title, conversation.title);
      expect(updated.createdAt, conversation.createdAt);
      expect(updated.updatedAt, later);
      expect(updated.archived, isTrue);
      expect(updated.titleOverridden, isFalse);
      expect(updated.messages, hasLength(2));
    });
  });
}
