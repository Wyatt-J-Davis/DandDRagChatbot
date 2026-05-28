import 'package:flutter/material.dart';

import '../services/summary_service.dart';
import '../state/app_state_notifier.dart';

class SummaryPage extends StatefulWidget {
  final AppStateNotifier appState;
  final SummaryService summaryService;

  SummaryPage({
    super.key,
    required this.appState,
    SummaryService? summaryService,
  }) : summaryService = summaryService ?? SummaryService();

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _isGenerating = false;
  String _progressMessage = '';
  int _progressValue = 0;
  String _phase = '';
  String? _summary;
  String? _error;

  String _detectPhase(String message) {
    if (message.contains('Summarizing')) return 'Map';
    if (message.contains('Combining')) return 'Reduce';
    if (message.contains('Writing') || message.contains('Generating')) {
      return 'Synthesis';
    }
    return '';
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _summary = null;
      _progressMessage = '';
      _progressValue = 0;
      _phase = '';
    });

    await for (final event in widget.summaryService.generate(
      model: widget.appState.selectedModel ?? '',
      partyMembers: widget.appState.partyMembers.toList(),
    )) {
      if (!mounted) return;
      if (event is SummaryProgressEvent) {
        setState(() {
          _progressValue = event.progress;
          _progressMessage = event.message;
          _phase = _detectPhase(event.message);
        });
      } else if (event is SummaryDoneEvent) {
        final summary = await widget.summaryService.fetchSummary();
        if (!mounted) return;
        setState(() {
          _summary = summary;
          _isGenerating = false;
        });
      } else if (event is SummaryErrorEvent) {
        setState(() {
          _error = event.message;
          _isGenerating = false;
        });
      }
    }

    if (mounted && _isGenerating) {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaign Summary',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generate,
            child: const Text('Generate Summary'),
          ),
          const SizedBox(height: 16),
          if (_isGenerating) ...[
            LinearProgressIndicator(value: _progressValue / 100),
            const SizedBox(height: 8),
            if (_phase.isNotEmpty)
              Chip(label: Text(_phase)),
            if (_progressMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_progressMessage),
              ),
          ],
          if (_error != null)
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          if (_summary != null && !_isGenerating)
            Expanded(
              child: SingleChildScrollView(
                child: Text(_summary!),
              ),
            ),
        ],
      ),
    );
  }
}
