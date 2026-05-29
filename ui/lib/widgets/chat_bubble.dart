import 'package:flutter/material.dart';

import '../services/chat_service.dart';

export '../services/chat_service.dart' show ChatSender;

class ChatBubble extends StatelessWidget {
  final String message;
  final ChatSender sender;

  const ChatBubble({super.key, required this.message, required this.sender});

  @override
  Widget build(BuildContext context) {
    final isUser = sender == ChatSender.user;
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color:
                isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
