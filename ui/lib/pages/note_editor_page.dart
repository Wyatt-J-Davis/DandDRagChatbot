import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class NoteEditorPage extends StatefulWidget {
  final QuillController? controller;

  const NoteEditorPage({super.key, this.controller});

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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
            child: QuillEditor.basic(controller: _controller),
          ),
        ],
      ),
    );
  }
}
