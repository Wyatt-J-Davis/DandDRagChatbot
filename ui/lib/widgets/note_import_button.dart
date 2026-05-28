import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../services/note_file_reader_service.dart';
import '../state/app_state_notifier.dart';

class NoteImportButton extends StatelessWidget {
  final QuillController controller;
  final AppStateNotifier appState;
  final NoteFileReaderService fileReader;

  NoteImportButton({
    super.key,
    required this.controller,
    required this.appState,
    NoteFileReaderService? fileReader,
  }) : fileReader = fileReader ?? const NoteFileReaderService();

  Future<void> _handleImport(BuildContext context) async {
    final path = appState.selectedNotesPath;
    if (path == null) return;

    final hasContent = controller.document.toPlainText().trim().isNotEmpty;

    if (hasContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace content?'),
          content: const Text(
              'Importing will replace the current editor content.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;
    }

    try {
      final text = await fileReader.readFile(path);
      if (!context.mounted) return;
      final docLength = controller.document.length;
      controller.replaceText(
        0,
        docLength > 0 ? docLength - 1 : 0,
        text,
        const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to read file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final hasPath = appState.selectedNotesPath != null;
        final button = ElevatedButton(
          onPressed: hasPath ? () => _handleImport(context) : null,
          child: const Text('Import'),
        );
        return hasPath
            ? button
            : Tooltip(
                message: 'No notes file uploaded',
                child: button,
              );
      },
    );
  }
}
