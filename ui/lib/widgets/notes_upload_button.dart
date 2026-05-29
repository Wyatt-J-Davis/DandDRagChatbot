import 'package:flutter/material.dart';

import '../services/file_picker_service.dart';
import '../services/upload_service.dart';
import '../state/app_state_notifier.dart';

class NotesUploadButton extends StatefulWidget {
  final AppStateNotifier appState;
  final FilePickerService pickerService;
  final UploadService uploadService;
  final VoidCallback? onSseStart;
  final VoidCallback? onSseDone;
  final VoidCallback? onUploadSuccess;

  const NotesUploadButton({
    super.key,
    required this.appState,
    required this.pickerService,
    required this.uploadService,
    this.onSseStart,
    this.onSseDone,
    this.onUploadSuccess,
  });

  @override
  State<NotesUploadButton> createState() => _NotesUploadButtonState();
}

class _NotesUploadButtonState extends State<NotesUploadButton> {
  bool _isUploading = false;
  int _uploadProgress = 0;
  String? _uploadError;
  bool _uploadSuccess = false;

  Future<void> _startUpload(String path) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadError = null;
      _uploadSuccess = false;
    });
    widget.onSseStart?.call();
    await for (final event in widget.uploadService.uploadNotes(path)) {
      if (!mounted) return;
      if (event is UploadProgressEvent) {
        setState(() => _uploadProgress = event.progress);
      } else if (event is UploadDoneEvent) {
        setState(() {
          _isUploading = false;
          _uploadSuccess = true;
        });
        widget.appState.setHasNotes(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes uploaded successfully')),
        );
        widget.onUploadSuccess?.call();
      } else if (event is UploadErrorEvent) {
        setState(() {
          _isUploading = false;
          _uploadError = event.message;
        });
      }
    }
    widget.onSseDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final path = widget.appState.selectedNotesPath;
        final filename = path != null ? _basename(path) : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                      final picked =
                          await widget.pickerService.pickNotesFile();
                      if (picked != null) {
                        widget.appState.setSelectedNotesPath(picked);
                        setState(() {
                          _uploadError = null;
                          _uploadSuccess = false;
                        });
                      }
                    },
              child: Text(
                  widget.appState.hasNotes ? 'Re-upload Notes' : 'Upload Notes'),
            ),
            if (filename != null) ...[
              const SizedBox(height: 4),
              Text(filename, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              if (!_isUploading)
                ElevatedButton(
                  onPressed: () => _startUpload(path!),
                  child: const Text('Vectorize'),
                ),
              if (_isUploading)
                LinearProgressIndicator(value: _uploadProgress / 100),
              if (_uploadSuccess) ...[
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Flexible(child: Text('Vectorization complete')),
                  ],
                ),
              ],
              if (_uploadError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _uploadError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).last;
}
