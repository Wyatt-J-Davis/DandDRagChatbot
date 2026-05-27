import 'package:flutter/material.dart';

import '../pages/note_editor_page.dart';
import '../pages/qa_page.dart';
import '../pages/summary_page.dart';
import '../services/chat_service.dart';
import '../services/file_picker_service.dart';
import '../services/model_service.dart';
import '../services/upload_service.dart';
import '../services/user_preferences_service.dart';
import '../state/app_state_notifier.dart';
import 'model_selector_dropdown.dart';
import 'notes_upload_button.dart';
import 'party_member_input.dart';
import 'sidebar_panel.dart';
import 'temperature_slider.dart';

class MainShell extends StatefulWidget {
  final AppStateNotifier appState;
  final ModelService modelService;
  final UserPreferencesService? prefsService;
  final FilePickerService? pickerService;
  final UploadService? uploadService;
  final ChatService? chatService;

  const MainShell({
    super.key,
    required this.appState,
    required this.modelService,
    this.prefsService,
    this.pickerService,
    this.uploadService,
    this.chatService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late Future<List<String>> _modelsFuture;

  static const List<NavigationRailDestination> _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: Text('Q&A'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.summarize_outlined),
      selectedIcon: Icon(Icons.summarize),
      label: Text('Summary'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: Text('Note Editor'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _modelsFuture = widget.modelService.fetchModels();
    if (widget.prefsService != null) {
      widget.appState.addListener(_savePreferences);
      _applyStoredPreferences();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_savePreferences);
    super.dispose();
  }

  Future<void> _applyStoredPreferences() async {
    final prefs = await widget.prefsService!.load();
    if (!mounted) return;
    widget.appState.setSelectedModel(prefs.model);
    widget.appState.setTemperature(prefs.temperature);
  }

  void _savePreferences() {
    widget.prefsService?.save(UserPreferences(
      model: widget.appState.selectedModel,
      temperature: widget.appState.temperature,
    ));
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return QAPage(
          appState: widget.appState,
          chatService: widget.chatService,
        );
      case 1:
        return const SummaryPage();
      case 2:
        return const NoteEditorPage();
      default:
        return QAPage(
          appState: widget.appState,
          chatService: widget.chatService,
        );
    }
  }

  void _retryFetchModels() {
    setState(() {
      _modelsFuture = widget.modelService.fetchModels();
    });
  }

  Widget? _buildSidebarChild() {
    if (_selectedIndex != 0) return null;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModelSelectorDropdown(
            modelsFuture: _modelsFuture,
            appState: widget.appState,
            onRetry: _retryFetchModels,
          ),
          const SizedBox(height: 12),
          TemperatureSlider(appState: widget.appState),
          const SizedBox(height: 12),
          PartyMemberInput(appState: widget.appState),
          const SizedBox(height: 12),
          NotesUploadButton(
            appState: widget.appState,
            pickerService: widget.pickerService ?? FilePickerService(),
            uploadService: widget.uploadService ?? UploadService(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          SidebarPanel(child: _buildSidebarChild()),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }
}
