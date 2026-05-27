import 'package:flutter/material.dart';

class QAPage extends StatefulWidget {
  const QAPage({super.key});

  @override
  State<QAPage> createState() => _QAPageState();
}

class _QAPageState extends State<QAPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) => ListTile(title: Text(_messages[index])),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
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
                    onPressed: value.text.trim().isEmpty ? null : _submit,
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
