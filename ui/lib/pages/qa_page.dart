import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../state/app_state_notifier.dart';
import '../widgets/chat_bubble.dart';

class _ChatMessage {
  final ChatSender sender;
  final String text;
  const _ChatMessage({required this.sender, required this.text});
}

class QAPage extends StatefulWidget {
  final AppStateNotifier appState;
  final ChatService chatService;

  QAPage({
    super.key,
    required this.appState,
    ChatService? chatService,
  }) : chatService = chatService ?? ChatService();

  @override
  State<QAPage> createState() => _QAPageState();
}

class _QAPageState extends State<QAPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final model = widget.appState.selectedModel ?? '';
    final temperature = widget.appState.temperature;

    setState(() {
      _messages.add(_ChatMessage(sender: ChatSender.user, text: text));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    await for (final event in widget.chatService.chat(
      question: text,
      model: model,
      temperature: temperature,
    )) {
      if (!mounted) return;
      if (event is ChatAnswerEvent) {
        setState(() {
          _messages
              .add(_ChatMessage(sender: ChatSender.assistant, text: event.answer));
          _isLoading = false;
        });
        _scrollToBottom();
      } else if (event is ChatErrorEvent) {
        setState(() {
          _messages.add(_ChatMessage(
              sender: ChatSender.assistant, text: 'Error: ${event.message}'));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }

    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return ChatBubble(message: msg.text, sender: msg.sender);
            },
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(hintText: 'Ask a question…'),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: (value.text.trim().isEmpty || _isLoading)
                        ? null
                        : _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
