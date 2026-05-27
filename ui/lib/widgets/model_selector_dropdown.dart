import 'package:flutter/material.dart';

import '../state/app_state_notifier.dart';

class ModelSelectorDropdown extends StatefulWidget {
  final Future<List<String>> modelsFuture;
  final AppStateNotifier appState;

  const ModelSelectorDropdown({
    super.key,
    required this.modelsFuture,
    required this.appState,
  });

  @override
  State<ModelSelectorDropdown> createState() => _ModelSelectorDropdownState();
}

class _ModelSelectorDropdownState extends State<ModelSelectorDropdown> {
  static const String _placeholder = 'No models available';

  late Future<List<String>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    _modelsFuture = widget.modelsFuture.then((models) {
      if (models.isNotEmpty && widget.appState.selectedModel == null) {
        widget.appState.setSelectedModel(models.first);
      }
      return models;
    }, onError: (_) => <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _modelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final models =
            (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data! : <String>[];
        final isEnabled = models.isNotEmpty;

        return ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            return DropdownButton<String>(
              value: isEnabled ? widget.appState.selectedModel : null,
              isExpanded: true,
              hint: const Text(_placeholder),
              onChanged: isEnabled
                  ? (value) => widget.appState.setSelectedModel(value)
                  : null,
              items: models
                  .map(
                    (m) => DropdownMenuItem<String>(value: m, child: Text(m)),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}
