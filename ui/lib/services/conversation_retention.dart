import '../models/conversation.dart';

/// Conversations inactive for longer than this are pruned on load, unless the
/// user has archived them.
const Duration conversationRetention = Duration(days: 14);

/// Returns [conversations] with every non-archived conversation whose
/// [Conversation.updatedAt] is older than [conversationRetention] removed.
///
/// Archived conversations are always retained regardless of age. The cutoff is
/// keyed on `updatedAt` (last activity), so a conversation the user keeps
/// returning to never expires. Pure and side-effect free for trivial unit
/// testing; order is preserved.
List<Conversation> pruneConversations(
  List<Conversation> conversations,
  DateTime now,
) {
  final cutoff = now.subtract(conversationRetention);
  return conversations
      .where((c) => c.archived || !c.updatedAt.isBefore(cutoff))
      .toList();
}
