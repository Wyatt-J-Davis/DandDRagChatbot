import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../services/file_picker_service.dart';
import '../services/note_content_service.dart';
import '../services/note_export_service.dart';
import '../state/operation_manager.dart';
import '../widgets/vectorize_button.dart';

class NoteEditorPage extends StatefulWidget {
  final QuillController? controller;
  final bool darkMode;
  final VoidCallback? onToggleDarkMode;
  final ScrollController? scrollController;
  final OperationManager? operationManager;
  final NoteContentService? noteContentService;
  final NoteExportService? noteExportService;
  final FilePickerService? filePickerService;

  const NoteEditorPage({
    super.key,
    this.controller,
    this.darkMode = false,
    this.onToggleDarkMode,
    this.scrollController,
    this.operationManager,
    this.noteContentService,
    this.noteExportService,
    this.filePickerService,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final QuillController _controller;

  bool get _exportEnabled =>
      widget.noteContentService != null &&
      widget.noteExportService != null &&
      widget.filePickerService != null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? QuillController.basic();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.document.toPlainText();
    final success = await widget.noteContentService!.saveNotes(content);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save notes')),
      );
    }
  }

  Future<void> _export(String format) async {
    final content = _controller.document.toPlainText();
    await widget.noteContentService!.saveNotes(content);

    final defaultName = 'notes.$format';
    final path = await widget.filePickerService!
        .pickSavePath(fileName: defaultName);
    if (path == null) return;

    final bytes = format == 'txt'
        ? await widget.noteExportService!.fetchTxtBytes()
        : await widget.noteExportService!.fetchDocxBytes();
    if (bytes == null) return;

    await File(path).writeAsBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final editorBg =
        widget.darkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final editorFg = widget.darkMode ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const ValueKey('header_row'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Notes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_exportEnabled) ...[
                TextButton(
                  onPressed: () => _export('txt'),
                  child: const Text('Export .txt'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _export('docx'),
                  child: const Text('Export .docx'),
                ),
                const SizedBox(width: 4),
              ],
              if (widget.noteContentService != null) ...[
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 4),
              ],
              if (widget.operationManager != null) ...[
                VectorizeButton(
                  controller: _controller,
                  operationManager: widget.operationManager!,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(
                    widget.darkMode ? Icons.light_mode : Icons.dark_mode),
                tooltip: widget.darkMode ? 'Light mode' : 'Dark mode',
                onPressed: widget.onToggleDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 16),
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showUndo: false,
              showRedo: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showLineHeightButton: false,
              multiRowsDisplay: false,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(color: editorFg),
              child: Container(
                key: const ValueKey('editor_background'),
                color: editorBg,
                child: QuillEditor.basic(
                  controller: _controller,
                  scrollController: widget.scrollController,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
