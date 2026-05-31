import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lottie/lottie.dart';

import '../services/summary_service.dart';
import '../state/app_state_notifier.dart';
import '../state/operation_manager.dart';

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
  final OperationManager operationManager;

  const SummaryPage({
    super.key,
    required this.appState,
    required this.operationManager,
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _isLoadingInitial = true;
  OperationStatus _previousSummaryStatus = OperationStatus.idle;

  @override
  void initState() {
    super.initState();
    widget.operationManager.addListener(_onManagerChange);
    _previousSummaryStatus = widget.operationManager.summaryStatus;
    _loadSummary();
  }

  @override
  void dispose() {
    widget.operationManager.removeListener(_onManagerChange);
    super.dispose();
  }

  void _onManagerChange() {
    if (!mounted) return;
    final status = widget.operationManager.summaryStatus;
    if (status == OperationStatus.done &&
        _previousSummaryStatus == OperationStatus.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary generated successfully')),
      );
    }
    _previousSummaryStatus = status;
    setState(() {});
  }

  Future<void> _loadSummary() async {
    await widget.operationManager.loadSummary();
    if (!mounted) return;
    setState(() => _isLoadingInitial = false);
  }

  void _generate() {
    widget.operationManager.startSummary(
      model: widget.appState.selectedModel ?? '',
      partyMembers: widget.appState.partyMembers.toList(),
      temperature: widget.appState.temperature,
    );
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
        heading: currentHeading,
        level: currentLevel,
        body: bodyLines.join('\n').trim(),
      ));
      bodyLines.clear();
    }

    for (final line in lines) {
      final match = RegExp(r'^(#{1,3})\s+(.+)').firstMatch(line);
      if (match != null) {
        flush();
        currentHeading = match.group(2)!.trim().replaceAll(RegExp(r'\*+'), '');
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

  Widget? _buildMetadataSubtitle(SummaryResult result) {
    final parts = <String>[
      if (result.model != null) 'Model: ${result.model}',
      if (result.generatedAt != null)
        'Generated: ${_formatDate(result.generatedAt!)}',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  •  '),
      style: const TextStyle(fontSize: 13, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = widget.operationManager.isSummaryRunning;
    final summaryResult = widget.operationManager.summaryResult;
    final hasResult = summaryResult != null;
    final error = widget.operationManager.summaryError;
    final progressValue = widget.operationManager.summaryProgress;
    final progressMessage = widget.operationManager.summaryProgressMessage;
    final phase = widget.operationManager.summaryPhase;
    final sections =
        hasResult ? _parseSections(summaryResult.summary) : <_SummarySection>[];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaign Summary',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (hasResult && !isGenerating) ...[
            const SizedBox(height: 4),
            if (_buildMetadataSubtitle(summaryResult) != null)
              _buildMetadataSubtitle(summaryResult)!,
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: isGenerating ? null : _generate,
                child: const Text('Generate Summary'),
              ),
              if (hasResult) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isGenerating ? null : _generate,
                  child: const Text('Regenerate'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (isGenerating) ...[
            Center(
              child: Lottie.asset(
                'assets/star-magic.json',
                width: 240,
                height: 240,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            LinearProgressIndicator(value: progressValue / 100),
            const SizedBox(height: 8),
            if (phase.isNotEmpty) Chip(label: Text(phase)),
            if (progressMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(progressMessage),
              ),
          ],
          if (error != null)
            Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
            ),
          if (!_isLoadingInitial && !hasResult && !isGenerating)
            const Text(
                'No summary yet. Use "Generate Summary" to create one.'),
          if (hasResult && !isGenerating)
            Expanded(
              child: sections.isEmpty
                  ? SingleChildScrollView(
                      child: MarkdownBody(data: summaryResult.summary))
                  : _buildSummaryWithToc(sections),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryWithToc(List<_SummarySection> sections) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: ListView(
            children: [
              for (final section in sections)
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
                for (final section in sections) ...[
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
                      child: MarkdownBody(data: section.body),
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
