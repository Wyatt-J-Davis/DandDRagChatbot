import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/file_picker_service.dart';
import '../state/app_state_notifier.dart';
import '../state/operation_manager.dart';

class NotesUploadButton extends StatefulWidget {
  final AppStateNotifier appState;
  final FilePickerService pickerService;
  final OperationManager operationManager;
  final VoidCallback? onUploadSuccess;

  const NotesUploadButton({
    super.key,
    required this.appState,
    required this.pickerService,
    required this.operationManager,
    this.onUploadSuccess,
  });

  @override
  State<NotesUploadButton> createState() => _NotesUploadButtonState();
}

class _NotesUploadButtonState extends State<NotesUploadButton> {
  OperationStatus _previousStatus = OperationStatus.idle;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChange);
    widget.operationManager.addListener(_onManagerChange);
    _syncState();
  }

  @override
  void didUpdateWidget(NotesUploadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationManager != widget.operationManager) {
      oldWidget.operationManager.removeListener(_onManagerChange);
      widget.operationManager.addListener(_onManagerChange);
      _syncState();
    }
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_onStateChange);
      widget.appState.addListener(_onStateChange);
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChange);
    widget.operationManager.removeListener(_onManagerChange);
    super.dispose();
  }

  void _syncState() {
    _previousStatus = widget.operationManager.uploadStatus;
    _showSuccess =
        widget.operationManager.uploadStatus == OperationStatus.done;
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _onManagerChange() {
    if (!mounted) return;
    final status = widget.operationManager.uploadStatus;
    if (status == OperationStatus.done &&
        _previousStatus == OperationStatus.running) {
      _showSuccess = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes uploaded successfully')),
      );
      widget.onUploadSuccess?.call();
    }
    if (status == OperationStatus.running) {
      _showSuccess = false;
    }
    _previousStatus = status;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = widget.operationManager.isUploadRunning;
    final isVectorizing = widget.operationManager.isVectorizeRunning;
    final isOperationRunning = isUploading || isVectorizing;
    final progress = widget.operationManager.uploadProgress;
    final error = widget.operationManager.uploadError;
    final path = widget.appState.selectedNotesPath;
    final filename = path != null ? _basename(path) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: isUploading
              ? null
              : () async {
                  final picked =
                      await widget.pickerService.pickNotesFile();
                  if (picked != null) {
                    widget.appState.setSelectedNotesPath(picked);
                    setState(() {
                      _showSuccess = false;
                    });
                  }
                },
          child: Text(
              widget.appState.hasNotes ? 'Re-upload Notes' : 'Upload Notes'),
        ),
        const SizedBox(height: 4),
        if (!isOperationRunning)
          Text(widget.appState.hasNotes ? 'Notes processed' : 'No notes loaded'),
        if (filename != null) ...[
          const SizedBox(height: 4),
          Text(filename, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          if (!isUploading)
            ElevatedButton(
              onPressed: () =>
                  widget.operationManager.startUpload(path: path!),
              child: const Text('Vectorize'),
            ),
          if (isUploading) ...[
            const SizedBox(height: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/Magical_Effect_Loading.json',
                  width: 80,
                  height: 80,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress / 100),
              ],
            ),
          ],
          if (_showSuccess) ...[
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Flexible(child: Text('Vectorization complete')),
              ],
            ),
          ],
          if (error != null && !isUploading && !_showSuccess) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ],
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).last;
}
