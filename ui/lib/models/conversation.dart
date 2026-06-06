import '../services/chat_service.dart';

/// A persisted, multi-turn grouping of Q&A exchanges.
///
/// A conversation is a client-side visual grouping only - each question is
/// still answered by independent, stateless RAG. The [archived] and
/// [titleOverridden] flags exist for later slices (archive / rename) and
/// default to `false`.
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool titleOverridden;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.titleOverridden = false,
    List<ChatMessage> messages = const [],
  }) : messages = List.unmodifiable(messages);

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    bool? archived,
    bool? titleOverridden,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      titleOverridden: titleOverridden ?? this.titleOverridden,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archived': archived,
        'titleOverridden': titleOverridden,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        archived: (json['archived'] as bool?) ?? false,
        titleOverridden: (json['titleOverridden'] as bool?) ?? false,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
