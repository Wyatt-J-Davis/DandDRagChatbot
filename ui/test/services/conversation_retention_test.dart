import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/models/conversation.dart';
import 'package:ttrpg_chatbot/services/conversation_retention.dart';

void main() {
  group('pruneConversations', () {
    final now = DateTime.parse('2026-06-06T12:00:00.000');

    Conversation conv({
      required String id,
      required DateTime updatedAt,
      bool archived = false,
    }) =>
        Conversation(
          id: id,
          title: id,
          createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
          updatedAt: updatedAt,
          archived: archived,
        );

    test('removes non-archived conversations idle for more than 14 days', () {
      final stale = conv(id: 'stale', updatedAt: now.subtract(const Duration(days: 15)));
      final result = pruneConversations([stale], now);
      expect(result, isEmpty);
    });

    test('retains archived conversations regardless of age', () {
      final ancient = conv(
        id: 'ancient',
        updatedAt: now.subtract(const Duration(days: 365)),
        archived: true,
      );
      final result = pruneConversations([ancient], now);
      expect(result.map((c) => c.id), ['ancient']);
    });

    test('retains a conversation updated within the last 14 days', () {
      final recent = conv(id: 'recent', updatedAt: now.subtract(const Duration(days: 13)));
      final result = pruneConversations([recent], now);
      expect(result.map((c) => c.id), ['recent']);
    });

    test('keys the cutoff on updatedAt, not createdAt', () {
      final oldCreatedRecentlyUpdated = Conversation(
        id: 'kept',
        title: 'kept',
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );
      final result = pruneConversations([oldCreatedRecentlyUpdated], now);
      expect(result.map((c) => c.id), ['kept']);
    });

    test('retains a conversation at exactly the 14-day boundary', () {
      final boundary = conv(id: 'boundary', updatedAt: now.subtract(const Duration(days: 14)));
      final result = pruneConversations([boundary], now);
      expect(result.map((c) => c.id), ['boundary']);
    });

    test('removes a conversation just past the 14-day boundary', () {
      final justPast = conv(
        id: 'past',
        updatedAt: now.subtract(const Duration(days: 14, seconds: 1)),
      );
      final result = pruneConversations([justPast], now);
      expect(result, isEmpty);
    });

    test('returns an empty list for empty input', () {
      expect(pruneConversations([], now), isEmpty);
    });

    test('keeps fresh and archived while dropping stale, preserving order', () {
      final fresh = conv(id: 'fresh', updatedAt: now.subtract(const Duration(days: 1)));
      final stale = conv(id: 'stale', updatedAt: now.subtract(const Duration(days: 30)));
      final archived = conv(
        id: 'archived',
        updatedAt: now.subtract(const Duration(days: 90)),
        archived: true,
      );
      final result = pruneConversations([fresh, stale, archived], now);
      expect(result.map((c) => c.id), ['fresh', 'archived']);
    });
  });
}
