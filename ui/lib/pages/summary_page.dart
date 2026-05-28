import 'package:flutter/material.dart';

import '../services/summary_service.dart';
import '../state/app_state_notifier.dart';

class _SummarySection {
  final String heading;
  final int level;
  final String body;
  final GlobalKey key;

  _SummarySection({
    required this.heading,
    required this.level,
    required this.body,
  }) : key = GlobalKey();
}

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
  bool _isLoadingInitial = true;
  bool _isGenerating = false;
  String _progressMessage = '';
  int _progressValue = 0;
  String _phase = '';
  String? _summary;
  String? _summaryModel;
  String? _summaryGeneratedAt;
  String? _error;
  List<_SummarySection> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final result = await widget.summaryService.fetchSummary();
    if (!mounted) return;
    setState(() {
      _summary = result?.summary;
      _summaryModel = result?.model;
      _summaryGeneratedAt = result?.generatedAt;
      _sections = result != null ? _parseSections(result.summary) : [];
      _isLoadingInitial = false;
    });
  }

  List<_SummarySection> _parseSections(String text) {
    final lines = text.split('\n');
    final sections = <_SummarySection>[];
    String? currentHeading;
    int currentLevel = 0;
    final bodyLines = <String>[];

    void flush() {
      if (currentHeading == null) return;
      sections.add(_SummarySection(
        heading: currentHeading!,
        level: currentLevel,
        body: bodyLines.join('\n').trim(),
      ));
      bodyLines.clear();
    }

    for (final line in lines) {
      final match = RegExp(r'^(#{1,3})\s+(.+)').firstMatch(line);
      if (match != null) {
        flush();
        currentHeading = match.group(2)!.trim();
        currentLevel = match.group(1)!.length;
      } else {
        bodyLines.add(line);
      }
    }
    flush();
    return sections;
  }

  String _formatDate(String isoDate) {
    try {
      return DateTime.parse(isoDate).toLocal().toString().split(' ')[0];
    } catch (_) {
      return isoDate;
    }
  }

  Widget? _buildMetadataSubtitle() {
    final parts = <String>[
      if (_summaryModel != null) 'Model: $_summaryModel',
      if (_summaryGeneratedAt != null) 'Generated: ${_formatDate(_summaryGeneratedAt!)}',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  •  '),
      style: const TextStyle(fontSize: 13, color: Colors.grey),
    );
  }

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
      _sections = [];
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
        final result = await widget.summaryService.fetchSummary();
        if (!mounted) return;
        setState(() {
          _summary = result?.summary;
          _summaryModel = result?.model;
          _summaryGeneratedAt = result?.generatedAt;
          _sections = result != null ? _parseSections(result.summary) : [];
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
          if (_summary != null && !_isGenerating) ...[
            const SizedBox(height: 4),
            if (_buildMetadataSubtitle() != null) _buildMetadataSubtitle()!,
          ],
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
          if (!_isLoadingInitial && _summary == null && !_isGenerating)
            const Text(
                'No summary yet. Use "Generate Summary" to create one.'),
          if (_summary != null && !_isGenerating)
            Expanded(
              child: _sections.isEmpty
                  ? SingleChildScrollView(child: Text(_summary!))
                  : _buildSummaryWithToc(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryWithToc() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: ListView(
            children: [
              for (final section in _sections)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.only(
                    left: (section.level - 1) * 12.0,
                    right: 8,
                  ),
                  title: Text(section.heading),
                  onTap: () {
                    if (section.key.currentContext != null) {
                      Scrollable.ensureVisible(
                        section.key.currentContext!,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
            ],
          ),
        ),
        const VerticalDivider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in _sections) ...[
                  Padding(
                    key: section.key,
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      section.heading,
                      style: TextStyle(
                        fontSize: section.level == 1
                            ? 20
                            : section.level == 2
                                ? 17
                                : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (section.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(section.body),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
