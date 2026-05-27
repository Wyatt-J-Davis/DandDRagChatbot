import 'package:flutter/material.dart';

import '../state/app_state_notifier.dart';

class PartyMemberInput extends StatefulWidget {
  final AppStateNotifier appState;

  const PartyMemberInput({super.key, required this.appState});

  @override
  State<PartyMemberInput> createState() => _PartyMemberInputState();
}

class _PartyMemberInputState extends State<PartyMemberInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.appState.addPartyMember(_controller.text);
    if (_controller.text.trim().isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(isDense: true),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Add'),
                ),
              ],
            ),
            ...widget.appState.partyMembers.map((name) => Text(name)),
          ],
        );
      },
    );
  }
}
