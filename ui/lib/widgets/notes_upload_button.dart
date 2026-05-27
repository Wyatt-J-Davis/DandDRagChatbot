import 'package:flutter/material.dart';

import '../services/file_picker_service.dart';
import '../state/app_state_notifier.dart';

class NotesUploadButton extends StatelessWidget {
  final AppStateNotifier appState;
  final FilePickerService pickerService;

  const NotesUploadButton({
    super.key,
    required this.appState,
    required this.pickerService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final path = appState.selectedNotesPath;
        final filename = path != null ? _basename(path) : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final picked = await pickerService.pickNotesFile();
                if (picked != null) appState.setSelectedNotesPath(picked);
              },
              child: const Text('Upload Notes'),
            ),
            if (filename != null) ...[
              const SizedBox(height: 4),
              Text(filename, overflow: TextOverflow.ellipsis),
            ],
          ],
        );
      },
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).last;
}
