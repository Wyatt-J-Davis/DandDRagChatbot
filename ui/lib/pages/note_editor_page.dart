import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../state/operation_manager.dart';
import '../widgets/vectorize_button.dart';

class NoteEditorPage extends StatefulWidget {
  final QuillController? controller;
  final bool darkMode;
  final VoidCallback? onToggleDarkMode;
  final ScrollController? scrollController;
  final OperationManager? operationManager;

  const NoteEditorPage({
    super.key,
    this.controller,
    this.darkMode = false,
    this.onToggleDarkMode,
    this.scrollController,
    this.operationManager,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final QuillController _controller;

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
            children: [
              const Text(
                'Notes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                    widget.darkMode ? Icons.light_mode : Icons.dark_mode),
                tooltip: widget.darkMode ? 'Light mode' : 'Dark mode',
                onPressed: widget.onToggleDarkMode,
              ),
            ],
          ),
          if (widget.operationManager != null) ...[
            const SizedBox(height: 8),
            VectorizeButton(
              controller: _controller,
              operationManager: widget.operationManager!,
            ),
          ],
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
