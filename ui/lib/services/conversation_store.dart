import 'dart:convert';
import 'dart:io';

import '../models/conversation.dart';
import 'conversation_retention.dart';

/// Persists the full conversation list to a local JSON file.
///
/// Mirrors [UserPreferencesService]: an injected [File], a load that falls back
/// to an empty list on a missing or corrupt file, and a synchronous save that
/// overwrites the whole list.
class ConversationStore {
  final File file;

  ConversationStore({required this.file});

  Future<List<Conversation>> load() async {
    if (!file.existsSync()) return [];
    try {
      final contents = await file.readAsString();
      final list = jsonDecode(contents) as List<dynamic>;
      final conversations = list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      final pruned = pruneConversations(conversations, DateTime.now());
      if (pruned.length != conversations.length) {
        await save(pruned);
      }
      return pruned;
    } on Exception {
      return [];
    }
  }

  Future<void> save(List<Conversation> conversations) async {
    final list = conversations.map((c) => c.toJson()).toList();
    file.writeAsStringSync(jsonEncode(list));
  }
}
