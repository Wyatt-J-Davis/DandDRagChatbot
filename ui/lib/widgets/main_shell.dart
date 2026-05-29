import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../pages/note_editor_page.dart';
import '../pages/qa_page.dart';
import '../pages/summary_page.dart';
import '../services/chat_service.dart';
import '../services/file_picker_service.dart';
import '../services/model_service.dart';
import '../services/note_content_service.dart';
import '../services/summary_service.dart';
import '../services/upload_service.dart';
import '../services/user_preferences_service.dart';
import '../services/status_service.dart';
import '../services/vectorize_service.dart';
import '../state/app_state_notifier.dart';
import 'model_selector_dropdown.dart';
import 'notes_upload_button.dart';
import 'vectorize_button.dart';
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
  final SummaryService? summaryService;
  final VectorizeService? vectorizeService;
  final NoteContentService? noteContentService;
  final StatusService? statusService;

  const MainShell({
    super.key,
    required this.appState,
    required this.modelService,
    this.prefsService,
    this.pickerService,
    this.uploadService,
    this.chatService,
    this.summaryService,
    this.vectorizeService,
    this.noteContentService,
    this.statusService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _noteEditorDarkMode = false;
  bool _sseActive = false;
  late final QuillController _noteController;

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

  void _onSseStart() => setState(() => _sseActive = true);
  void _onSseDone() => setState(() => _sseActive = false);

  @override
  void initState() {
    super.initState();
    _noteController = QuillController.basic();
    _modelsFuture = widget.modelService.fetchModels();
    if (widget.prefsService != null) {
      widget.appState.addListener(_savePreferences);
      _applyStoredPreferences();
    }
    _loadNotes();
    _loadStatus();
  }

  @override
  void dispose() {
    _noteController.dispose();
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

  Future<void> _loadStatus() async {
    if (widget.statusService == null) return;
    try {
      final hasNotes = await widget.statusService!.fetchHasNotes();
      if (!mounted) return;
      widget.appState.setHasNotes(hasNotes);
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    if (widget.noteContentService == null) return;
    final text = await widget.noteContentService!.fetchNotes();
    if (!mounted || text.isEmpty) return;
    final len = _noteController.document.length;
    _noteController.replaceText(
      0,
      len > 0 ? len - 1 : 0,
      text,
      const TextSelection.collapsed(offset: 0),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return QAPage(
          appState: widget.appState,
          chatService: widget.chatService,
        );
      case 1:
        return SummaryPage(
          appState: widget.appState,
          summaryService: widget.summaryService,
          onSseStart: _onSseStart,
          onSseDone: _onSseDone,
        );
      case 2:
        return NoteEditorPage(
          controller: _noteController,
          darkMode: _noteEditorDarkMode,
          onToggleDarkMode: () =>
              setState(() => _noteEditorDarkMode = !_noteEditorDarkMode),
        );
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
    switch (_selectedIndex) {
      case 0:
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
                onSseStart: _onSseStart,
                onSseDone: _onSseDone,
                onUploadSuccess: () { _loadNotes(); },
              ),
            ],
          ),
        );
      case 2:
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: VectorizeButton(
            controller: _noteController,
            vectorizeService: widget.vectorizeService,
            onSseStart: _onSseStart,
            onSseDone: _onSseDone,
          ),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          IgnorePointer(
            ignoring: _sseActive,
            child: Opacity(
              opacity: _sseActive ? 0.38 : 1.0,
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: _destinations,
              ),
            ),
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
