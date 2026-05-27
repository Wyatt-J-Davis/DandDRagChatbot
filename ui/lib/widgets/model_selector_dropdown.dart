import 'package:flutter/material.dart';

import '../state/app_state_notifier.dart';

class ModelSelectorDropdown extends StatefulWidget {
  final Future<List<String>> modelsFuture;
  final AppStateNotifier appState;
  final VoidCallback onRetry;

  const ModelSelectorDropdown({
    super.key,
    required this.modelsFuture,
    required this.appState,
    required this.onRetry,
  });

  @override
  State<ModelSelectorDropdown> createState() => _ModelSelectorDropdownState();
}

class _ModelSelectorDropdownState extends State<ModelSelectorDropdown> {
  static const String _errorMessage = 'No models found. Is Ollama running?';

  late Future<List<String>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(ModelSelectorDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.modelsFuture, widget.modelsFuture)) {
      setState(_initFuture);
    }
  }

  void _initFuture() {
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

        if (!isEnabled) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(_errorMessage),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          );
        }

        return ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            return DropdownButton<String>(
              value: widget.appState.selectedModel,
              isExpanded: true,

              onChanged: (value) => widget.appState.setSelectedModel(value),
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
