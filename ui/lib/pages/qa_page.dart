import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/chat_service.dart';
import '../state/app_state_notifier.dart';
import '../state/operation_manager.dart';
import '../state/typewriter_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/reference_chip.dart';

class QAPage extends StatefulWidget {
  final AppStateNotifier appState;
  final OperationManager operationManager;

  const QAPage({
    super.key,
    required this.appState,
    required this.operationManager,
  });

  @override
  State<QAPage> createState() => _QAPageState();
}

class _QAPageState extends State<QAPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  OperationStatus _previousChatStatus = OperationStatus.idle;

  TypewriterController? _typewriterController;
  int? _typingMessageIndex;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChange);
    widget.operationManager.addListener(_onManagerChange);
    _previousChatStatus = widget.operationManager.chatStatus;
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChange);
    widget.operationManager.removeListener(_onManagerChange);
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _typewriterController?.removeListener(_onTypewriterTick);
    _typewriterController?.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _onManagerChange() {
    if (!mounted) return;
    final status = widget.operationManager.chatStatus;
    if (status == OperationStatus.done &&
        _previousChatStatus == OperationStatus.running) {
      final messages = widget.appState.chatHistory;
      final lastIndex = messages.length - 1;
      if (lastIndex >= 0 && messages[lastIndex].sender == ChatSender.assistant) {
        _startTypewriter(messages[lastIndex].text, lastIndex);
      }
    }
    if (status != OperationStatus.running &&
        _previousChatStatus == OperationStatus.running) {
      _inputFocus.requestFocus();
    }
    _previousChatStatus = status;
    setState(() {});
    _scrollToBottom();
  }

  void _startTypewriter(String text, int messageIndex) {
    _typewriterController?.removeListener(_onTypewriterTick);
    _typewriterController?.dispose();
    _typewriterController = null;
    _typingMessageIndex = null;

    if (text.isEmpty) return;

    _typewriterController = TypewriterController(fullText: text);
    _typingMessageIndex = messageIndex;
    _typewriterController!.addListener(_onTypewriterTick);
    _typewriterController!.start();
  }

  void _onTypewriterTick() {
    if (!mounted) return;
    if (_typewriterController?.isDone == true) {
      _typewriterController!.removeListener(_onTypewriterTick);
      setState(() => _typingMessageIndex = null);
    } else {
      setState(() {});
    }
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

  void _showSourceDialog(BuildContext context, ChatSource source) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: SingleChildScrollView(child: Text(source.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.operationManager.isChatRunning) return;

    widget.appState.addChatMessage(
      ChatMessage(sender: ChatSender.user, text: text),
    );
    _controller.clear();
    _scrollToBottom();

    widget.operationManager.startChat(
      question: text,
      model: widget.appState.selectedModel ?? '',
      temperature: widget.appState.temperature,
    );
  }

  Widget _buildInputRow(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _inputFocus,
            enabled: !isLoading,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Ask a question…'),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return IconButton(
              icon: const Icon(Icons.send),
              onPressed:
                  (value.text.trim().isEmpty || isLoading) ? null : _submit,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.appState.chatHistory;
    final isLoading = widget.operationManager.isChatRunning;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧙', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildInputRow(isLoading),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isTyping = index == _typingMessageIndex;
              final displayText = isTyping
                  ? (_typewriterController?.displayedText ?? '')
                  : msg.text;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatBubble(message: displayText, sender: msg.sender),
                  if (!isTyping &&
                      msg.sender == ChatSender.assistant &&
                      msg.sources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          for (var i = 0; i < msg.sources.length; i++)
                            ReferenceChip(
                              index: i + 1,
                              date: msg.sources[i].date,
                              onTap: () =>
                                  _showSourceDialog(context, msg.sources[i]),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (isLoading)
          Center(
            child: Lottie.asset(
              'assets/star-magic.json',
              width: 240,
              height: 240,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildInputRow(isLoading),
        ),
      ],
    );
  }
}
