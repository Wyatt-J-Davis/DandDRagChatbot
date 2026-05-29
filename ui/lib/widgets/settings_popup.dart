import 'package:flutter/material.dart';

import '../services/file_picker_service.dart';
import '../services/model_service.dart';
import '../state/app_state_notifier.dart';
import '../state/operation_manager.dart';
import 'model_selector_dropdown.dart';
import 'notes_upload_button.dart';

class SettingsPopup extends StatefulWidget {
  final AppStateNotifier appState;
  final OperationManager operationManager;
  final Future<List<String>> modelsFuture;
  final VoidCallback onModelRetry;
  final FilePickerService pickerService;
  final VoidCallback? onUploadSuccess;

  const SettingsPopup({
    super.key,
    required this.appState,
    required this.operationManager,
    required this.modelsFuture,
    required this.onModelRetry,
    required this.pickerService,
    this.onUploadSuccess,
  });

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup> {
  final _memberController = TextEditingController();

  @override
  void dispose() {
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    widget.appState.addPartyMember(_memberController.text);
    if (_memberController.text.trim().isNotEmpty) {
      _memberController.clear();
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionLabel('Model'),
              ModelSelectorDropdown(
                modelsFuture: widget.modelsFuture,
                appState: widget.appState,
                onRetry: widget.onModelRetry,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _sectionLabel('Temperature'),
                  const Spacer(),
                  Text(widget.appState.temperature.toStringAsFixed(1)),
                ],
              ),
              Slider(
                min: 0.0,
                max: 1.0,
                value: widget.appState.temperature,
                onChanged: widget.appState.setTemperature,
              ),
              const Divider(height: 24),
              _sectionLabel('Party Members'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberController,
                      decoration: const InputDecoration(isDense: true),
                      onSubmitted: (_) => _addMember(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addMember,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const Divider(height: 24),
              _sectionLabel('Note Taker'),
              Text(
                'Whose perspective the AI answers from',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...widget.appState.partyMembers.map(
                (name) => RadioListTile<String>(
                  value: name,
                  groupValue: widget.appState.noteTaker,
                  onChanged: (v) => widget.appState.setNoteTaker(v),
                  title: Text(
                    name,
                    style: name == widget.appState.noteTaker
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => widget.appState.removePartyMember(name),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Divider(height: 24),
              _sectionLabel('Notes'),
              NotesUploadButton(
                appState: widget.appState,
                pickerService: widget.pickerService,
                operationManager: widget.operationManager,
                onUploadSuccess: widget.onUploadSuccess,
              ),
            ],
          );
        },
      ),
    );
  }
}
